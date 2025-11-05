#!/bin/bash

# ================================================================================
# SCRIPT DE CONFIGURAÇÃO AUTOMÁTICA DO SERVIDOR DHCP (KEA) EM CENTOS 10
# Autor: Daniel Santos
# Curso: CET Gestão de Redes e Sistemas Computacionais - ATEC
# Projeto: Automação de DNS em ambiente CentOS10
# Versão: Final (DHCP)
# Data: Outubro 2025
# Descrição:
#   Este script instala e configura automaticamente o serviço Kea (DHCP),
#   permitindo o funcionamento de um servidor DHCP interno na rede à sua escolha.
#   Suporta dois modos de operação:
#       (1) NAT + SEGMENT  → o servidor DHCP funciona como gateway da LAN
#       (2) SEGMENT        → o servidor DHCP obtém Internet de outro servidor (ex: DNS)
#   Inclui ainda firewall (Firewalld), segurança com Fail2Ban, e um menu
#   interativo para gestão do DHCP (ver leases, logs, etc).
# ================================================================================

# ================================================================================
# BARRA LOADING - guardada dentro de "barra_loading()"
# O que faz barra_loading() - Invoca a função toda
# ================================================================================
barra_loading() {
    echo -ne "A aplicar alterações: ["
    for i in {1..20}; do
        echo -ne "#"
        sleep 0.04
    done
    echo "] Concluído!"
    echo
}

# ================================================================================
# Menu inicial - Escolher entre (1) Instalar ou (2) Menu de gestão:
#
# 1): Instala e configura
# 2): Menu de gestão para adicionar, consultar registos, ver logs, etc.
# ================================================================================
clear
echo "=============================================="
echo " CONFIGURAÇÃO DO SERVIDOR DHCP (KEA) "
echo "=============================================="
sleep 0.5
echo
echo "1) Instalar e configurar DHCP (Kea)"
echo "2) Menu de gestão"
echo
echo "--------------------------------------------"
read -p "Escolha uma opção (1 ou 2): " OPCAO
echo "--------------------------------------------"
barra_loading
clear

# ================================================================================
# OPÇÃO 1 - Instalar e configurar DHCP
# ================================================================================
if [ "$OPCAO" -eq 1 ]; then
  echo
  echo
  echo "================================================"
  echo " INSTALAÇÃO E CONFIGURAÇÃO DO DHCP (KEA) "
  echo "================================================"
  echo
  echo "Esta VM tem:"
  echo " 1) NAT + SEGMENT (Gateway para rede interna)"
  echo " 2) SEGMENT (Rede interna apenas)"
  echo
  echo "------------------------------------------------"
  read -p " Escolha uma opção (1 ou 2): " ADAPTER
  echo "------------------------------------------------"
  barra_loading
  clear

  # ----------------------------------------------------------------------------
  # Verificação das interfaces de rede / Pedido de nomes se necessário
  # ----------------------------------------------------------------------------
  echo "A verificar interfaces de rede disponíveis:"
  echo "----------------------------------------------"
  nmcli device status | grep ethernet

  # Verificação da interface NAT (ens160)
  if nmcli device | grep -q "ens160"; then
    INT_NAT="ens160"
  else
    read -p "Introduza o nome da interface NAT: " INT_NAT
  fi

  # Verificação da interface LAN (ens224)
  if nmcli device | grep -q "ens224"; then
    INT_LAN="ens224"
  else
    read -p "Introduza o nome da interface LAN: " INT_LAN
  fi

  # Mostrar interfaces selecionadas
  barra_loading
  echo
  echo "----------------------------------------------"
  echo " Interface NAT selecionada: $INT_NAT"
  echo " Interface LAN selecionada: $INT_LAN"
  echo "----------------------------------------------"
  sleep 0.5

  # ----------------------------------------------------------------------------
  # Pedido de IPs, gateway, e domínio
  #
  # Defaults (ENTER para assumir defaults):
  # - IP do DNS: 192.168.26.254
  # - IP do DHCP: 192.168.26.10
  # - Domínio interno: atecgrsc.com
  #----------------------------------------------------------------------------
  echo
  echo "=============================================="
  echo " Designação de IPs e do domínio interno:"
  echo "=============================================="
  echo

  # Pedido do IP do servidor DHCP
  read -p "IP deste servidor DHCP (ex: 192.168.26.10): " IP_DHCP
  IP_DHCP=${IP_DHCP:-192.168.26.10}
  echo
  sleep 0.5
  
  # IP do servidor DNS
  read -p "Servidor DNS (ex: 192.168.26.254): " IP_DNS
  IP_DNS=${IP_DNS:-192.168.26.254}
  echo
  sleep 0.5

  # Pedido do domínio interno
  read -p "Domínio interno (ex: atecgrsc.com): " DOMINIO
  DOMINIO=${DOMINIO:-atecgrsc.com}
  echo
  sleep 0.5

  # Pedido do Range DHCP
  echo "Configurar o range DHCP a atribuir aos clientes:"
  read -p "Início do range DHCP (ex: 192.168.26.50): " IP_RANGE_INICIO
  IP_RANGE_INICIO=${IP_RANGE_INICIO:-192.168.26.50}
  sleep 0.5
  read -p "Fim do range DHCP (ex: 192.168.26.200): " IP_RANGE_FIM
  IP_RANGE_FIM=${IP_RANGE_FIM:-192.168.26.200}
  echo

 # Definir IP Estático na interface LAN (DHCP) / Ativar interface
  nmcli con add type ethernet ifname "$INT_LAN" con-name "$INT_LAN" ipv4.addresses "$IP_DHCP/24" ipv4.method manual
  nmcli con up "$INT_LAN"

  # ----------------------------------------------------------------------------
  # Configurações se for ADAPTER (1) / ADAPTER (2)
  # ----------------------------------------------------------------------------

  # ADAPTER (1) - (NAT + SEGMENT) - Gateway é ele próprio
  if [ "$ADAPTER" -eq 1 ]; then
    echo "A ativar IP Forwarding..."
    barra_loading
    # Ativar IP Forwarding temporariamente
    sudo sysctl -w net.ipv4.ip_forward=1
    echo
    echo "A persistir configuração de IP Forwarding..."
    barra_loading
    # Masquerade O que faz - Adiciona regra de masquerading (NAT) permanente
    sudo firewall-cmd --zone=public --add-masquerade --permanent
    echo
    echo "A associar interfaces à zona 'public' e a permitir o encaminhamento..."
    barra_loading
    # Associar interfaces à zona pública e permitir encaminhamento
    sudo firewall-cmd --zone=public --add-interface=ens160 --permanent
    sudo firewall-cmd --zone=public --add-interface=ens224 --permanent
    sudo firewall-cmd --zone=internal --add-forward --permanent
    echo
    echo "A adicionar regras diretas ao firewall para NAT..."
    barra_loading
    # Regras diretas para permitir encaminhamento entre interfaces
    sudo firewall-cmd --direct --add-rule ipv4 filter FORWARD 0 -i $INT_LAN -o $INT_NAT -j ACCEPT
    sudo firewall-cmd --direct --add-rule ipv4 filter FORWARD 0 -i $INT_NAT -o $INT_LAN -m state --state RELATED,ESTABLISHED -j ACCEPT
    echo
    echo "A recarregar regras do firewall..."
    barra_loading
    sudo firewall-cmd --reload

    # NAT + SEGMENT - gateway é o próprio servidor DHCP
    IP_GATEWAY="$IP_DHCP"

  else
    # ADAPTER 2 - (SEGMENT) - Configurar gateway e ligação temporária
    echo "A configurar gateway e ligação temporária para acesso à Internet..."
    nmcli con down "$INT_LAN"
    nmcli con mod "$INT_LAN" ipv4.gateway "$IP_DNS"
    nmcli con mod "$INT_LAN" ipv4.dns "8.8.8.8"
    nmcli con up "$INT_LAN"

    # SEGMENT - gateway é o servidor DNS
    IP_GATEWAY="$IP_DNS"
  fi

  
  # ----------------------------------------------------------------------------
  # Instalar pacotes necessários (com acesso à net já estabelecido)
  # ----------------------------------------------------------------------------
  # Instalar Kea
  sudo dnf install kea -y
  # Instalar Kea e firewalld
  dnf install -y firewalld

  # ----------------------------------------------------------------------------
  # Instalar Fail2Ban
  # ----------------------------------------------------------------------------
  # Instalar EPEL repositório (necessário para Fail2Ban)
  dnf install -y epel-release
  sleep 0.5
  # Instalar Fail2Ban
  dnf install -y fail2ban > /dev/null 2>&1
  sleep 0.5
  # Ativa e inicia o serviço Fail2Ban
  systemctl enable --now fail2ban
  systemctl restart fail2ban
  sleep 0.5
  echo

  # ----------------------------------------------------------------------------
  # Voltar a configurar interface LAN com DNS correto (remover temporário)
  # ----------------------------------------------------------------------------
  nmcli con mod "$INT_LAN" ipv4.dns "$IP_DNS"

  # ----------------------------------------------------------------------------
  # Configurar firewall para DHCP
  # ----------------------------------------------------------------------------
  sudo systemctl enable --now firewalld
  firewall-cmd --permanent --add-service=dhcp
  sudo firewall-cmd --reload
  sleep 0.5
  echo

  # ----------------------------------------------------------------------------
  # Preparar logging do Kea (criar antes para evitar erros)
  # ----------------------------------------------------------------------------
  # Criar diretório de logs
  mkdir -p /var/log/kea
  # Criar ficheiro de logs
  touch /var/log/kea/kea-dhcp4.log
  # Dar permissões de escrita ao ficheiro de logs
  chmod 666 /var/log/kea/kea-dhcp4.log

  # ----------------------------------------------------------------------------
  # Calcular subnet a partir do IP do servidor DHCP
  # ----------------------------------------------------------------------------
  # Extrair os primeiros 3 octetos do IP_DHCP e adicionar .0/24
  SUBNET_BASE="$(echo $IP_DHCP | cut -d'.' -f1-3).0/24"

  # ----------------------------------------------------------------------------
  # Gerar ficheiro /etc/kea/kea-dhcp4.conf
  # ----------------------------------------------------------------------------

  # Preparar diretório e ficheiro de configuração do Kea (criar antes para evitar erros)
  sudo mkdir -p /etc/kea
  sudo touch /etc/kea/kea-dhcp4.conf
  sleep 0.5
  echo

  echo "A gerar configuração do Kea DHCP..."
  cat > /etc/kea/kea-dhcp4.conf <<EOF
{
  "Dhcp4": {
    "valid-lifetime": 600,
    "renew-timer": 300,
    "rebind-timer": 540,

    "interfaces-config": {
      "interfaces": [ "$INT_LAN" ]
    },

    "subnet4": [
      {
        "id": 1,
        "subnet": "$SUBNET_BASE",
        "pools": [
          { "pool": "$IP_RANGE_INICIO-$IP_RANGE_FIM" }
        ],
        "option-data": [
          { "name": "routers", "data": "$IP_GATEWAY" },
          { "name": "domain-name-servers", "data": "$IP_DNS" },
          { "name": "domain-name", "data": "$DOMINIO" }
        ]
      }
    ],

    "lease-database": {
      "type": "memfile",
      "persist": true,
      "name": "/var/lib/kea/dhcp4.leases"
    },

    "loggers": [
      {
        "name": "kea-dhcp4",
        "output_options": [
          { "output": "/var/log/kea/kea-dhcp4.log" }
        ],
        "severity": "INFO"
      }
    ]
  }
}
EOF

  echo "Ficheiro /etc/kea/kea-dhcp4.conf criado."
  sleep 1


  # ----------------------------------------------------------------------------
  # Ativar serviço Kea DHCP
  # ----------------------------------------------------------------------------
  systemctl enable --now kea-dhcp4
  sleep 0.5
  echo
  # Verificar estado do serviço
  # O que faz sed -n '1,6p': mostra apenas as primeiras 6 linhas da saída
  systemctl status kea-dhcp4 --no-pager | sed -n '1,6p'
  sleep 0.5

  echo
  echo "DHCP (Kea) instalado e configurado com sucesso!"
  echo "Usa a opção 2 do menu para ver leases e logs."

  # ----------------------------------------------------------------------------
  # Guardar dados (persistência simples para o menu de gestão) 
  # ----------------------------------------------------------------------------
  echo "$IP_DHCP" > /tmp/ip_dhcp_server.txt
  echo "$IP_GATEWAY" > /tmp/ip_gateway.txt
  echo "$IP_DNS" > /tmp/ip_dns_to_clients.txt
  echo "$DOMINIO" > /tmp/dominio_dhcp.txt
  echo "$IP_RANGE_INICIO" > /tmp/range_inicio.txt
  echo "$IP_RANGE_FIM" > /tmp/range_fim.txt
  echo "$SUBNET_BASE" > /tmp/subnet_base.txt
  echo "$INT_LAN" > /tmp/int_lan.txt

  # ----------------------------------------------------------------------------
  # Fim da OPÇÃO 1 - Instalar e configurar DHCP
  # ----------------------------------------------------------------------------
  exit 0
fi


# ================================================================================
# OPÇÃO 2 - Menu de Gestão
# (DHCP já deve estar instalado)
# ================================================================================


# Ler dados (variáveis perdem valores após script acabar, isto guarda, para o menu de gestão)
IP_DHCP=$(cat /tmp/ip_dhcp_server.txt)
IP_GATEWAY=$(cat /tmp/ip_gateway.txt)
IP_DNS=$(cat /tmp/ip_dns_to_clients.txt)
DOMINIO=$(cat /tmp/dominio_dhcp.txt)
IP_RANGE_INICIO=$(cat /tmp/range_inicio.txt)
IP_RANGE_FIM=$(cat /tmp/range_fim.txt)
SUBNET_BASE=$(cat /tmp/subnet_base.txt)
INT_LAN=$(cat /tmp/int_lan.txt)

# ================================================================================
# Menu de gestão
# O que faz [-s /var/lib/kea/dhcp4.leases]: verifica se o ficheiro de leases existe e não está vazio
# O que faz tail -n 20: mostra as últimas 20 linhas do ficheiro de logs
# ================================================================================
while true; do
  clear
  echo "========== MENU DE GESTÃO DO DHCP (KEA) ================="
  echo
  echo "Interface LAN: $INT_LAN"
  echo "Rede:          $SUBNET_BASE"
  echo "Range da Pool: $IP_RANGE_INICIO - $IP_RANGE_FIM"
  echo "Servidor DHCP: $IP_DHCP"
  echo "Servidor DNS:  $IP_DNS"
  echo "Gateway:       $IP_GATEWAY"
  echo "Domínio:       $DOMINIO"
  echo
  echo "========================================================="
  echo
  echo "1) Ver leases ativas (/var/lib/kea/dhcp4.leases)"
  echo "2) Ver últimos logs (/var/log/kea/kea-dhcp4.log)"
  echo "3) Verificar porta de escuta (ss -lun | grep 67)"
  echo "4) Instruções de testes de resolução DHCP para clientes"
  echo "5) Sair"
  echo
  echo "---------------------------------------------------------"
  read -p "Opção: " OPT
  echo

  # O que faz - case : Verifica o valor da variável "OPT"
  case "$OPT" in
    1)
      echo
      echo "-----------------------------------------------------"
      echo "                 LEASES ATIVAS                      "
      echo "-----------------------------------------------------"
      barra_loading
      echo
      if [ -s /var/lib/kea/dhcp4.leases ]; then
        cat /var/lib/kea/dhcp4.leases
        systemctl reload kea-dhcp4
      else
        echo "Nenhuma lease atribuída ainda."
      fi
      echo
      echo "--------------------------------"
      read -p "Enter para continuar..."
      ;;
    2)
      echo
      echo "-----------------------------------------------------"
      echo "                LOGS RECENTES                   "
      echo "-----------------------------------------------------"
      barra_loading
      echo
      tail -n 20 /var/log/kea/kea-dhcp4.log 2>/dev/null || echo "Sem logs ainda."
      systemctl reload kea-dhcp4
      echo
      echo "--------------------------------"
      read -p "Enter para continuar..."
      ;;
    3)
      echo
      echo "-----------------------------------------------------"
      echo "          VERIFICAR PORTA DE ESCUTA              "
      echo "-----------------------------------------------------"
      barra_loading
      echo
      ss -lun | grep 67 || echo "O Kea DHCP não está a escutar na porta 67."
      systemctl reload kea-dhcp4
      echo
      echo "-----------------------------------------------------"
      read -p "Enter para continuar..."
      ;;
    4)
      echo
      echo "------------------------------------------------------------"
      echo "  INSTRUÇÕES DE TESTES DE RESOLUÇÃO DHCP PARA CLIENTES       "
      echo "------------------------------------------------------------"
      barra_loading
      echo
      echo "Testes a realizar a partir dos clientes Linux e Windows:"
      echo
      echo "1) Verificar se o cliente recebeu IP automaticamente:"
      echo "   - Linux: ifconfig"
      echo "   - Windows: ipconfig /all"
      echo "   Esperado: um IP dentro do intervalo configurado (ex: 192.168.26.50–200)"
      echo
      echo "2) Confirmar gateway e DNS atribuídos pelo DHCP:"
      echo "   - Linux: cat /etc/resolv.conf"
      echo "   - Windows: ipconfig /all"
      echo "   Esperado: Gateway: ${IP_GATEWAY} e DNS: ${IP_DNS}"
      echo
      echo "3) Testar conectividade local (LAN):"
      echo "   - ping ${IP_GATEWAY}"
      echo "   - ping ${IP_DNS}"
      echo
      echo "4) Testar acesso à Internet (se o gateway tem NAT ativo):"
      echo "   - ping 8.8.8.8           # Teste de conectividade externa"
      echo "   - ping www.google.com    # Teste de resolução + saída"
      echo
      echo "5) Testar libertação e renovação de IP (caso o DHCP esteja ativo):"
      echo "   - Linux: nmcli device reapply ens33 e nmcli device disconnect ens33 && nmcli device connect ens33"
      echo "   - Windows: ipconfig /release e ipconfig /renew"
      echo "  Esperado: novo IP dentro do intervalo DHCP"
      echo
      echo "6) Verificar logs de atribuição no servidor DHCP:"
      echo "   - tail -f /var/log/kea/kea-dhcp4.log"
      echo "   Esperado: registos de ALLOCATED com os IPs atribuídos."
      echo
      echo
      echo "--------------------------------"
      read -p "Enter para continuar..."
      ;;
    5)
      echo "--------------------------------"
      echo "A sair do programa..."
      barra_loading
      echo "--------------------------------"
      clear
      exit 0
      ;;
    *)
      echo "Opção inválida!"
      sleep 1
      ;;
  esac
done
fi


# ===============================================================================
# Fim do script
# ===============================================================================
