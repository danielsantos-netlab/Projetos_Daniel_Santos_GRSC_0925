#!/bin/bash

# ================================================================================
# SCRIPT DE CONFIGURAÇÃO AUTOMÁTICA DO SERVIDOR DNS (BIND)
# Autor: Daniel Santos
# Curso: CET Gestão de Redes e Sistemas Computacionais - ATEC
# Projeto: Automação de DNS em ambiente CentOS10
# Versão: Final (DNS)
# Data: Outubro 2025
# Descrição:
#   Este script instala e configura automaticamente o serviço BIND (DNS),
#   permitindo o funcionamento de um servidor DNS interno na rede à sua escolha.
#   Suporta dois modos de operação:
#       (1) NAT + SEGMENT  → o servidor DNS funciona como gateway da LAN
#       (2) SEGMENT        → o servidor DNS obtém Internet de outro servidor (ex: DHCP)
#   Inclui ainda firewall (Firewalld), segurança com Fail2Ban, e um menu
#   interativo para criação e gestão de registos (direta e inversa).
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
# 1): Instala pacotes, configura rede, firewall, BIND, Fail2Ban, zonas
# 2): Menu de gestão para adicionar registos, ver zonas, instruções de teste
# ================================================================================
clear
echo "================================================"
echo " CONFIGURAÇÃO DO SERVIDOR DNS (BIND) "
echo "================================================"
echo
echo " 1) Instalar e configurar DNS (BIND)"
echo " 2) Menu de gestão"
echo
echo "------------------------------------------------"
read -p " Escolha uma opção (1 ou 2): " OPCAO
echo "------------------------------------------------"
barra_loading
clear

# ================================================================================
# OPÇÃO 1 - Instalar e configurar DNS
# ================================================================================
if [ "$OPCAO" -eq 1 ]; then
  echo
  echo
  echo "=============================================="
  echo " INSTALAÇÃO E CONFIGURAÇÃO DO DNS (BIND) "
  echo "=============================================="
  echo
  echo " Esta VM tem:"
  echo " 1) NAT + SEGMENT (Gateway para rede interna)"
  echo " 2) SEGMENT (Rede interna apenas)"
  echo
  echo "----------------------------------------------"
  read -p " Escolha uma opção (1 ou 2): " ADAPTER
  echo "----------------------------------------------"
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
  echo "----------------------------------------------"

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

  # Pedido do IP do DNS
  read -p "IP do DNS (ex: 192.168.26.254): " IP_DNS
  IP_DNS=${IP_DNS:-192.168.26.254}
  echo
  sleep 0.5
 
  # Pedido do IP do DHCP
  read -p "IP do DHCP (ex: 192.168.26.10): " IP_DHCP
  IP_DHCP=${IP_DHCP:-192.168.26.10}
  echo
  sleep 0.5
  
  # Pedido do domínio interno
  read -p "Domínio interno (ex: atecgrsc.com): " DOMINIO
  DOMINIO=${DOMINIO:-atecgrsc.com} 
  echo
  sleep 0.5

  # Definir IP Estático na interface LAN (DNS) / Ativar interface
  if ! nmcli con show "$INT_LAN" &>/dev/null; then
    echo "A criar ligação $INT_LAN..."
    nmcli con add type ethernet ifname "$INT_LAN" con-name "$INT_LAN" ipv4.addresses "$IP_DNS/24" ipv4.method manual
  else
  # Modificar IP se a ligação já existir
    echo "Ligação $INT_LAN já existe, a configurar IP..."
    nmcli con mod "$INT_LAN" ipv4.addresses "$IP_DNS/24"
    nmcli con mod "$INT_LAN" ipv4.method manual
  fi
  echo
  sleep 0.5

  # Ativar ligação LAN
  echo "A ativar ligação $INT_LAN..."
  barra_loading
  nmcli con up "$INT_LAN"
  sleep 0.5
  echo

  # ----------------------------------------------------------------------------
  # Configurações se for - NAT + SEGMENT (1) / SEGMENT (2)
  # ----------------------------------------------------------------------------

  # ADAPTER (1) - (NAT + SEGMENT) - Gateway é ele próprio
  if [ "$ADAPTER" -eq 1 ]; then
    echo "A ativar e iniciar o serviço firewalld..."
    barra_loading
    # Ativar e iniciar o serviço firewalld
    sudo systemctl enable --now firewalld
    sleep 0.5
    echo
    echo "A ativar IP Forwarding..."
    barra_loading
    # Ativar IP Forwarding temporariamente
    sudo sysctl -w net.ipv4.ip_forward=1
    sleep 0.5
    echo
    echo "A persistir configuração de IP Forwarding..."
    barra_loading
    # Masquerade O que faz - Adiciona regra de masquerading (NAT) permanente
    sudo firewall-cmd --zone=public --add-masquerade --permanent
    sleep 0.5
    echo
    echo "A associar interfaces à zona 'public' e a permitir o encaminhamento..."
    barra_loading
    # Associar interfaces à zona pública e permitir encaminhamento
    sudo firewall-cmd --zone=public --add-interface=$INT_NAT --permanent
    sudo firewall-cmd --zone=public --add-interface=$INT_LAN --permanent
    sudo firewall-cmd --zone=internal --add-forward --permanent
    sleep 0.5
    echo
    echo "A recarregar regras do firewall..."
    barra_loading
    sudo firewall-cmd --reload
    sleep 0.5
    echo

    # NAT + SEGMENT - gateway é o próprio servidor DNS
    IP_GATEWAY="$IP_DNS"
  
  else
    # ADAPTER 2 - (SEGMENT) - Configurar gateway e ligação temporária
    echo "A configurar gateway e ligação temporária para acesso à Internet..."
    barra_loading
    nmcli con mod "$INT_LAN" ipv4.gateway "$IP_DHCP"
    nmcli con mod "$INT_LAN" ipv4.dns "8.8.8.8"
    nmcli con up "$INT_LAN"
    echo

    # SEGMENT - gateway é o servidor DHCP
    IP_GATEWAY="$IP_DHCP"
  fi

  # ----------------------------------------------------------------------------
  # Instalar BIND e dependências
  # ----------------------------------------------------------------------------
  # Instalar bind, bind-utils
  echo "A instalar BIND e dependências..."
  barra_loading
  dnf install -y bind bind-utils
  sleep 0.5
  echo
  
  # ----------------------------------------------------------------------------
  # Instalar e ativar firewalld
  # ----------------------------------------------------------------------------
  echo "A instalar e ativar o firewalld..."
  barra_loading
  dnf install -y firewalld
  sleep 0.5
  echo
  echo "A ativar e iniciar o serviço firewalld..."
  barra_loading
  systemctl enable --now firewalld
  sudo firewall-cmd --reload
  sleep 0.5
  echo

  # ----------------------------------------------------------------------------
  # Instalar Fail2Ban
  # ----------------------------------------------------------------------------
  # Instalar EPEL repositório (necessário para Fail2Ban)
  echo "A instalar repositório EPEL..."
  barra_loading
  dnf install -y epel-release
  sleep 0.5
  echo
  # Instalar Fail2Ban
  echo "A instalar o pacote Fail2Ban..."
  barra_loading
  dnf install -y fail2ban
  sleep 0.5
  echo
  # Ativa e inicia o serviço Fail2Ban
  echo "A ativar e iniciar o serviço Fail2Ban..."
  barra_loading
  systemctl enable --now fail2ban
  systemctl restart fail2ban
  sleep 0.5
  echo

  # ----------------------------------------------------------------------------
  # Voltar a configurar interface LAN com DNS correto (remover temporário)
  # ----------------------------------------------------------------------------
  nmcli con mod "$INT_LAN" ipv4.dns "$IP_DNS"

  # ----------------------------------------------------------------------------
  # Configurar firewall para DNS
  # ----------------------------------------------------------------------------
  firewall-cmd --permanent --add-service=dns
  sudo firewall-cmd --reload

  # ----------------------------------------------------------------------------
  # Calcular rede e nomes dos ficheiros
  # ----------------------------------------------------------------------------
  # REDE_PREFIX: Extrai os primeiros 3 octetos do IP
  # O que faz - cut -d'.' -f1-3: Usa o ponto como delimitador e extrai os 3 primeiros campos
  REDE_PREFIX=$(echo "$IP_DNS" | cut -d'.' -f1-3)

  # O que faz - awk -F'.': Usa o ponto como delimitador e inverte os octetos + in-addr.arpa
  REV_SUFFIX=$(echo "$REDE_PREFIX" | awk -F'.' '{print $3"."$2"."$1".in-addr.arpa"}')

  # ZONA_INV: Nome do ficheiro de zona inversa
  ZONA_INV=$(echo "$REDE_PREFIX" | awk -F'.' '{print $3"."$2"."$1".db"}')

  # DNS_LAST=${IP_DNS##*.}: Extrair últimos octetos para registos PTR
  DNS_LAST=${IP_DNS##*.}

  # DHCP_LAST=${IP_DHCP##*.}: Extrai o último octeto do IP do DHCP
  DHCP_LAST=${IP_DHCP##*.}

  # ----------------------------------------------------------------------------
  # Preparação de diretórios e ficheiros (para evitar possíveis erros)
  # ----------------------------------------------------------------------------
  # Criar diretórios
  mkdir -p /var/log/named > /dev/null 2>&1
  mkdir -p /var/named > /dev/null 2>&1

  # Criar ficheiro
  touch /etc/named.conf > /dev/null 2>&1
  touch /var/named/${DOMINIO}.db > /dev/null 2>&1
  touch /var/named/${ZONA_INV} > /dev/null 2>&1

  # Definir permissões
  echo "A definir permissões corretas..."
  barra_loading
  chown named:named /var/log/named /var/named
  chown named:named /var/named/* /var/log/named
  chown root:named /etc/named.conf
  sleep 0.5
  echo

  # Definir permissões para os ficheiros de zona
  echo "A definir permissões corretas nos ficheiros de zona..."
  barra_loading
  chown named:named /var/named/${DOMINIO}.db /var/named/${ZONA_INV}
  chmod 644 /var/named/${DOMINIO}.db /var/named/${ZONA_INV}
  sleep 0.5
  echo

  # Definir permissões de execução para o diretório /var/named
  echo "A definir permissões de execução para os diretórios..."
  barra_loading
  chmod 755 /var/named
  chmod 755 /var/log/named
  sleep 0.5
  echo

  # ----------------------------------------------------------------------------
  # Criação e configuração de /etc/named.conf
  #
  # Opções:
  #  - listen-on any  → escuta em todas as interfaces IPv4
  #  - recursion yes  → permite consultas recursivas para clientes
  #  - forwarders     → encaminhadores públicos (Google + Cloudflare)
  # Zonas:
  #  - zona direta   → DOMINIO.db
  #  - zona inversa  → ZONA_INV
  # ----------------------------------------------------------------------------

  cat > /etc/named.conf <<EOF
options {
    directory "/var/named";
    listen-on port 53 { any; };
    listen-on-v6 { none; };
    allow-query { any; };
    recursion yes;
    forwarders { 8.8.8.8; 1.1.1.1; };
};
logging {
    channel default_debug {
        file "/var/log/named/named.log";
        severity dynamic;
    };
};
zone "${DOMINIO}" IN {
    type master;
    file "${DOMINIO}.db";
};
zone "${REV_SUFFIX}" IN {
    type master;
    file "${ZONA_INV}";
};
EOF

  # ----------------------------------------------------------------------------
  # Criação das zonas direta e inversa
  # - Direta  - (nome para IP)
  # - Inversa - (IP para nome)
  # ----------------------------------------------------------------------------
  cat > /var/named/${DOMINIO}.db <<EOF
\$TTL 1D
@   IN SOA  ns1.${DOMINIO}. admin.${DOMINIO}. (
        2024102601 ; Serial
        1D ; Refresh
        1H ; Retry
        1W ; Expire
        3H ) ; Minimum TTL
    IN  NS  ns1.${DOMINIO}.
ns1 IN  A   ${IP_DNS}
srvdhcp IN  A ${IP_DHCP}
EOF

  cat > /var/named/${ZONA_INV} <<EOF
\$TTL 1D
@   IN SOA  ns1.${DOMINIO}. admin.${DOMINIO}. (
        2024102601 ; Serial
        1D ; Refresh
        1H ; Retry
        1W ; Expire
        3H ) ; Minimum TTL
    IN  NS  ns1.${DOMINIO}.
${DNS_LAST}  IN PTR ns1.${DOMINIO}.
${DHCP_LAST} IN PTR srvdhcp.${DOMINIO}.
EOF

  # ----------------------------------------------------------------------------
  # Calcular subnet a partir do IP do servidor DNS
  # ----------------------------------------------------------------------------
  # Extrair os primeiros 3 octetos do IP_DNS e adicionar .0/24
  SUBNET_BASE="$(echo $IP_DNS | cut -d'.' -f1-3).0/24"

  # Guardar SUBNET_BASE em ficheiro temporário
  echo "$SUBNET_BASE" > /tmp/subnet_base.txt
  sleep 0.5

  # ----------------------------------------------------------------------------
  # Ativar serviço named
  # ----------------------------------------------------------------------------
  echo "A ativar e iniciar o serviço named (BIND)..."
  barra_loading
  systemctl enable --now named
  sleep 0.5
  echo
  barra_loading
  echo
  echo "DNS instalado e configurado com sucesso!"
  sleep 0.5
  echo
  echo "Use a opção 2 do menu para gerir registos."


  # ----------------------------------------------------------------------------
  # Guardar dados (persistência simples para o menu de gestão) 
  # ----------------------------------------------------------------------------
  echo "$DOMINIO" > /tmp/dominio.txt
  echo "$IP_DNS" > /tmp/ip_dns.txt
  echo "$IP_DHCP" > /tmp/ip_dhcp.txt
  echo "$INT_LAN" > /tmp/int_lan.txt
  echo "$SUBNET_BASE" > /tmp/subnet_base.txt
  echo "$IP_GATEWAY" > /tmp/ip_gateway.txt
  echo "$REDE_PREFIX" > /tmp/rede_prefix.txt
  echo "$ZONA_INV" > /tmp/zona_inv.txt

  # ----------------------------------------------------------------------------
  # Fim da OPÇÃO 1 - Instalar e configurar DNS
  # - exit 0 para sair do script após a instalação
  # ----------------------------------------------------------------------------
  exit 0
fi

# ================================================================================
# OPÇÃO 2 - Menu de Gestão
# (DNS já deve estar instalado)
# ================================================================================

# Ler dados (variáveis perdem valores após script acabar, isto guarda, para o menu de gestão)
DOMINIO=$(cat /tmp/dominio.txt)
IP_DNS=$(cat /tmp/ip_dns.txt)
IP_DHCP=$(cat /tmp/ip_dhcp.txt)
INT_LAN=$(cat /tmp/int_lan.txt)
SUBNET_BASE=$(cat /tmp/subnet_base.txt)
IP_GATEWAY=$(cat /tmp/ip_gateway.txt)
REDE_PREFIX=$(echo "$IP_DNS" | cut -d'.' -f1-3)
ZONA_INV=$(echo "$REDE_PREFIX" | awk -F'.' '{print $3"."$2"."$1".db"}')



# ----------------------------------------------------------------------------
# Menu de gestão
# ----------------------------------------------------------------------------
while true; do
  clear
  echo "========== MENU DE GESTÃO DO DNS ========================"
  echo
  echo "Interface LAN: $INT_LAN"
  echo "Rede:          $SUBNET_BASE"
  echo "Servidor DNS:  $IP_DNS"
  echo "Servidor DHCP: $IP_DHCP"
  echo "Gateway:       $IP_GATEWAY"
  echo "Domínio:       $DOMINIO"
  echo
  echo "========================================================="
  echo
  echo "1) Adicionar registo (direta + inversa)"
  echo "2) Ver zona direta"
  echo "3) Ver zona inversa"
  echo "4) Instruções de testes de resolução DNS para clientes"
  echo "5) Sair"
  echo
  echo "---------------------------------------------------------"
  read -p "Opção: " OPT
  echo

  # O que faz - case : Verifica o valor da variável "OPT"
  case "$OPT" in
    1)
      read -p "Nome do host (ex: CLI01): " HOSTNAME
      HOSTNAME=${HOSTNAME:-CLI01}
      echo
      read -p "IP (ex: ${REDE_PREFIX}.50): " HOST_IP
      HOST_IP=${HOST_IP:-${REDE_PREFIX}.50}

      # Extrair Último Octeto para registo PTR (Pointer Record) - (Ip para nome)
      OCTETO=$(echo "$HOST_IP" | cut -d'.' -f4)

      # Adicionar registos à zona direta e inversa
      echo "${HOSTNAME}  IN  A  ${HOST_IP}" >> /var/named/${DOMINIO}.db
      echo "${OCTETO}  IN  PTR  ${HOSTNAME}.${DOMINIO}." >> /var/named/${ZONA_INV}

      # Reload Serviço
      systemctl reload named
      barra_loading
      echo "Registos adicionados com sucesso!"
      echo
      echo "---------------------------------------------------------"
      read -p "Enter para continuar..."
      ;;
    2)
      echo "---------------------------------------------------------"
      barra_loading
      # Mostrar zona direta
      echo
      cat /var/named/${DOMINIO}.db
      echo
      echo "---------------------------------------------------------"
      read -p "Enter para continuar..."
      ;;
    3)
      echo "---------------------------------------------------------"
      barra_loading
      # Mostrar zona inversa
      echo
      cat /var/named/${ZONA_INV}
      echo
      echo "---------------------------------------------------------"
      read -p "Enter para continuar..."
      ;;
    4)
      clear
      echo "========================================================="
      echo "  INSTRUÇÕES DE TESTES DE RESOLUÇÃO DNS PARA CLIENTES     "
      echo "========================================================="
      echo
      sleep 0.5
      echo "---------------------------------------------------------"
      echo "Testes a realizar a partir dos clientes Linux e Windows:"
      echo "---------------------------------------------------------"
      echo
      echo "1) Verificar se o cliente obteve o DNS correto ${IP_DNS}"
      echo "   - Linux: cat /etc/resolv.conf"
      echo "   - Windows: ipconfig /all"
      echo
      echo "2) Testar resolução de nomes internos (zona direta)"
      echo "   - Linux: nslookup ns1.${DOMINIO}"
      echo "   - Windows: nslookup ns1.${DOMINIO}"
      echo "   Esperado: resposta com o IP ${IP_DNS}"
      echo
      echo "3) Testar resolução inversa (zona inversa)"
      echo "   - Linux: dig -x ${IP_DNS}"
      echo "   - Windows: nslookup ${IP_DNS}"
      echo "   Esperado: resposta com o nome ns1.${DOMINIO}"
      echo
      echo "4) Testar encaminhamento externo (forwarders)"
      echo "   - ping www.google.com"
      echo "   - nslookup www.google.com"
      echo "   Esperado: resposta com IP público e tempo de resposta."
      echo
      echo "5) Verificar logs de consultas no servidor DNS:"
      echo "   - sudo tail -f /var/log/named/query.log"
      echo
      echo "------------------------------------------------------------"
      read -p "Enter para continuar..."
      ;;
    5)
      echo "------------------------------------------------------------"
      echo "A sair do programa..."
      barra_loading
      clear
      echo "------------------------------------------------------------"
      exit 0 ;;
    *)
      echo "Opção inválida!"
      sleep 1
      ;;
  esac
done
fi

# ============================================================================
# Fim do script
# ============================================================================
