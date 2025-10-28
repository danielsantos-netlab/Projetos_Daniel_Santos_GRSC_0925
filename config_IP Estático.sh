#!/bin/bash

# ============================================================================
#  Script: config_dns_V6_final.sh
#  Autor: Daniel Santos
#  Descrição:
#  Este script configura um IP estático numa VM Linux.
#  O script verifica se a VM está em Bridge ou LAN Segment antes de aplicar.
#  Em modo NAT, o script avisa que não é necessário IP estático e sai.
#  O script pede o IP, máscara e gateway ao utilizador.
#  O script aplica as configurações e testa a conectividade com ping.
#
#  Data: 2024-06-10
# ============================================================================

# ============================================================================
# Função estética para barra de "loading" (só visual / opcional)
# Mantida da versão anterior para feedback visual.
# ============================================================================
barra_loading() {
  echo -ne "A aplicar alterações: ["
  for i in {1..20}; do
    echo -ne "#"
    sleep 0.05
  done
  echo "] Concluído!"
  echo
}

# ============================================================================
# Configuração do IP estático
# ============================================================================
clear
echo "======================================================"
echo " Configuração de IP Estático para VM Linux "
echo "======================================================"
sleep 1
echo ""
echo "Este script só deve ser usado se a VM estiver em:"
echo "   - Bridge, ou LAN Segment"
echo ""
read -p "A VM está em Bridge ou LAN Segment? (s/n): " RESPOSTA

if [[ "$RESPOSTA" != "s" && "$RESPOSTA" != "S" ]]; then
    echo ""
    echo "Operação cancelada. Em modo NAT não é necessário IP estático."
    echo "Saindo..."
    barra_loading
    exit 0
fi

echo ""
echo "VM está no modo correto. Vamos continuar..."
barra_loading

# Mostrar as interfaces disponíveis
echo "Interfaces de rede encontradas:"
barra_loading
ip -br a | awk '$2=="UP" {print $1, $2}'

# Identificar a interface principal (geralmente a ativa)
INTERFACE=$(ip -br a | awk '$2=="UP" {print $1}' | head -n1)

echo ""
echo "Interface principal detetada: $INTERFACE"
barra_loading
read -p "Deseja usar esta interface? (s/n): " RESPOSTA

# Se não for a interface correta, pedir ao utilizador para indicar
if [[ "$RESPOSTA" != "s" && "$RESPOSTA" != "S" ]]; then
    read -p "Digite o nome da interface que quer configurar: " INTERFACE
fi

# Identificar o nome da connection associada à interface
CONNECTION=$(nmcli -t -f NAME,DEVICE connection show | grep "$INTERFACE" | cut -d: -f1)

# Pedir o IP desejado
read -p "Digite o IP que quer atribuir (ex: 192.168.26.10): " IP
IP=${IP:-192.168.26.10}

# Pedir a máscara (valor por defeito /24 se não escrever nada)
read -p "Digite a máscara (ex: 24) [Enter para /24]: " MASCARA
MASCARA=${MASCARA:-24}

# Pedir o gateway (opcional)
read -p "Digite o gateway (ex: 192.168.26.254) [Enter se não quiser]: " GATEWAY

# Aplicar o IP estático com nmcli
echo ""
echo "A configurar IP estático em $INTERFACE ..."
sudo nmcli con mod "$CONNECTION" ipv4.addresses "$IP/$MASCARA"
sudo nmcli con mod "$CONNECTION" ipv4.method manual

# Só adiciona o gateway se tiver sido indicado
if [ -n "$GATEWAY" ]; then
    sudo nmcli con mod "$CONNECTION" ipv4.gateway "$GATEWAY"
fi

# Configurar DNS e ativar a conexão
sudo nmcli con mod "$CONNECTION" ipv4.dns "8.8.8.8"
sudo nmcli con up "$CONNECTION"

# IP fixo fica permanente mesmo após reboot
sudo nmcli con mod "$CONNECTION" connection.autoconnect yes

# Confirmar
echo ""
echo "Configuração aplicada com sucesso!"
barra_loading
echo "Teste de conectividade (ping para 8.8.8.8)"
ping -c 3 8.8.8.8
echo ""
barra_loading
echo "Teste ping concluído com sucesso."

# Fim do script