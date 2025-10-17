#!/bin/bash

#
# =========================================================================================
#
# Projeto: Configuração de Servidor FTP com Diretórios Isolados e Permissões Específicas
# Autor: Sérgio Correia / Daniel Santos / Martinho Marques
# Data: 01 10 2025
#
# Descrição:
# Este script configura um servidor FTP usando vsftpd em modo ativo,
# cria um utilizador de demonstração, define diretórios isolados com
# permissões específicas e assegura que apenas utilizadores autorizados
# podem aceder ao servidor FTP.
#
# =========================================================================================#
#

# O set -e é um comando a correr em Scripts para que este pare a execução
# se houver algum erro em qualquer comando.

set -e

# 1 - Instalar pacotes necessários
# O que faz: Instala o cliente FTP, o servidor VSFTPD e a ferramenta SELinux.
# O que faz o -y do dnf: Responde automaticamente "sim" a todas as perguntas durante a instalação.

sudo dnf install -y ftp
sudo dnf install -y vsftpd
sudo dnf -y install vsftpd policycoreutils-python-utils
echo "Instalar o Servidor e da ferramenta do SELinux."
sleep 0.5

# 2 - Iniciar o Serviço
# O que faz: Arranca o serviço vsftpd.

sudo systemctl start vsftpd
echo "Iniciar e ativar o Serviço"
sleep 0.5

# 3 - Verificar o Status do Serviço
# O que faz: Mostra o estado atual do serviço vsftpd.

sudo systemctl status vsftpd
echo "Status do Serviço"
sleep 0.5

# 4 - Abrir a porta 21 na Firewall
# O que faz: Adiciona uma regra permanente na firewall para permitir o tráfego FTP.
# O que faz o --permanent: Torna a regra permanente, sobrevivendo a reinícios.
# O que faz o --add-service=ftp: Adiciona o serviço FTP (porta 21) à lista de serviços permitidos.

sudo firewall-cmd --permanent --add-service=ftp
sudo systemctl reload firewalld

echo "Abrir a porta 21 da Firewall"
sleep 0.5

# 5 - Configurar vsftpd.conf
# O que faz: Substitui a configuração do vsftpd por opções básicas (sem anónimos,
# permite utilizadores locais, chroot, ativa apenas modo ativo, define diretórios).

# O que faz o tee >/dev/null: Redireciona a saída do comando tee para /dev/null, suprimindo a saída no terminal.

sudo tee /etc/vsftpd/vsftpd.conf >/dev/null <<'CONF'
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES
local_root=/home/userftp/ftp
connect_from_port_20=YES
ftp_data_port=20
pasv_enable=NO
pam_service_name=vsftpd
file_open_mode=0222
local_umask=000

CONF

# O que faz cada destas opções:
# listen=YES: Ativa o modo standalone (não via inetd).
# listen_ipv6=NO: Desativa o suporte IPv6.
# anonymous_enable=NO: Desativa o login anónimo.
# local_enable=YES: Permite o login de utilizadores locais.
# write_enable=YES: Permite operações de escrita (upload, criação de diretórios).
# chroot_local_user=YES: Restringe utilizadores locais ao seu diretório home.
# local_root=/home/userftp/ftp: Define o diretório raiz para utilizadores locais.
# connect_from_port_20=YES: Usa a porta 20 para conexões de dados.
# ftp_data_port=20: Define a porta de dados FTP para 20.
# pasv_enable=NO: Desativa o modo passivo.
# pam_service_name=vsftpd: Define o serviço PAM a usar para autenticação.
# file_open_mode=0222: Define permissões padrão para arquivos criados (escrita apenas).
# local_umask=000: Define a máscara de permissão para arquivos criados por utilizadores locais.


# O que é o serviço PAM? Pluggable Authentication Modules (PAM) é um sistema
# flexível de autenticação que permite a integração de múltiplos métodos de
# autenticação em aplicações. O vsftpd usa PAM para autenticar utilizadores
# locais, verificando as credenciais contra o sistema de autenticação do Linux.

echo "Feitas as alterações no conf do VSFTPD."
sleep 0.5

# 6 - Criar Utilizador de Demonstração e Diretórios Isolados
# O que faz: Cria um utilizador chamado userftp com shell nologin e
# define a estrutura de diretórios com permissões específicas.
# Se o utilizador já existir, o comando ignora erros simples.

# O que faz o id userftp 2>/dev/null || ... : Verifica se o utilizador userftp existe; se não existir, cria-o.
# O que faz o -m do useradd: Cria o diretório home do utilizador se não existir. - Create home directory
# O que faz o -s do useradd: Define o shell do utilizador. Aqui usamos /usr/sbin/nologin para impedir login interativo. - Shell
# O que faz o chpasswd: Define a senha do utilizador a partir da entrada padrão. - Change password

if ! id userftp &>/dev/null; then
  sudo useradd -m -s /usr/sbin/nologin userftp
  echo 'userftp:1234' | sudo chpasswd
fi
sleep 0.5

# Extra - Barra de Progresso para a criação do utilizador
# e aplicação das permissões
# O que faz o -n do echo: Impede o echo de adicionar uma nova linha após a saída, permitindo que a barra de progresso seja exibida na mesma linha. - No newline

echo -n "[ "

for i in {1..40}; do
	echo -n "="
	sleep 0.1
done

echo -n " ]"

echo " Utilizador de demonstração criado (userftp:1234)."
sleep 0.5

# 7 - Assegurar que /usr/sbin/nologin está em /etc/shells

# O que faz: Adiciona /usr/sbin/nologin a /etc/shells se não estiver lá.
# O que faz o -q do grep: Pesquisa silenciosamente (sem saída) - Quiet
# O que faz o -x do grep: Garante que a linha corresponde exatamente. - Exact
# O que faz o -F do grep: Trata o padrão como uma string fixa (não regex). - Fixed

grep -qxF '/usr/sbin/nologin' /etc/shells || echo '/usr/sbin/nologin' | sudo tee -a /etc/shells >/dev/null
sleep 0.5

# 8 - Criar a Estrutura de Diretórios
# O que faz: Cria os diretórios /home/userftp/ftp/download e /home/userftp/ftp/upload
# com permissões específicas para isolamento.

# O que faz o -d do install: Cria diretórios. - Directory
# O que faz o -m do install: Define as permissões do diretório. - Mode
# O que faz o -o do install: Define o proprietário do diretório. - Owner
# O que faz o -g do install: Define o grupo do diretório. - Group

sudo install -d -m 0755 -o root    -g root    /home/userftp/ftp
sudo install -d -m 0755 -o userftp -g userftp /home/userftp/ftp/upload
sudo install -d -m 0555 -o userftp -g userftp /home/userftp/ftp/download
sleep 0.5

# 9 - Configurar Permissões de Isolamento
# O que faz: Define as permissões corretas para os diretórios criados,
# garantindo que o utilizador userftp só pode escrever na pasta upload.

# O que faz o semanage fcontext -a -t public_content_rw_t ...: Adiciona uma regra ao SELinux para permitir leitura e escrita nos diretórios upload e download.
# O que faz o semanage fcontext -a -t public_content_t ...: Adiciona uma regra ao SELinux para permitir leitura no diretório download.
# O que faz o restorecon -R /home/userftp/ftp: Restaura os contextos de segurança do SELinux recursivamente no diretório /home/userftp/ftp.

# O que faz o -a do semanage: Adiciona uma nova regra.
# O que faz o -t do semanage: Define o tipo de contexto SELinux.
# O que faz o -R do restorecon: Aplica recursivamente a política SELinux.

sudo semanage fcontext -a -t public_content_rw_t "/home/userftp/ftp/{upload,download}(/.*)?"
sudo semanage fcontext -a -t public_content_t    "/home/userftp/ftp/download(/.*)?"
sudo restorecon -R /home/userftp/ftp
sudo restorecon -R /home/userftp/ftp/upload
sleep 0.5

# 10 - Configurar a Lista de Utilizadores Permitidos (Whitelist)
# O que faz: Cria o ficheiro /etc/vsftpd/user_list se não existir
# e adiciona userftp a essa lista para permitir o login.

# O que faz o touch: Cria um ficheiro vazio se não existir. - Create file
# O que faz o grep -q "^userftp$" ...: Verifica silenciosamente se o utilizador userftp está na lista de utilizadores permitidos. - Quiet
# O que faz o tee -a: Anexa a saída a um ficheiro em vez de sobrescrevê-lo. - Append

sudo touch /etc/vsftpd/user_list
if ! grep -q "^userftp$" /etc/vsftpd/user_list 2>/dev/null; then
  echo "userftp" | sudo tee -a /etc/vsftpd/user_list >/dev/null
fi

# 11 - Ativar a Lista de Utilizadores Permitidos
# O que faz: Configura o vsftpd para usar a lista de utilizadores
# e reinicia o serviço.

# O que faz o --now do systemctl: Ativa o serviço para iniciar automaticamente na inicialização e inicia-o imediatamente.

sudo systemctl enable --now vsftpd
sudo systemctl restart vsftpd
echo "Restart do serviço."

# Extra - Barra de Progresso para a espera do reinício do serviço

# O que faz o -n do echo: Impede o echo de adicionar uma nova linha após a saída, permitindo que a barra de progresso seja exibida na mesma linha. - No newline

echo -n "[ "

for i in {1..40}; do
	echo -n "="
	sleep 0.1
done

echo -n " ]"

# 12 - Resumo Final

echo " Resumo final:"

echo "Configuração do servidor FTP concluída."
sleep 0.5
echo "Utilizador: userftp"
sleep 0.5
echo "Password: 1234"
sleep 0.5
echo "Diretórios:"
sleep 0.5
echo "  /home/userftp/ftp/upload   (escrita permitida)"
sleep 0.5
echo "  /home/userftp/ftp/download (somente leitura)"
sleep 0.5
echo "Modo: ATIVO (ftp_data_port=20, pasv_enable=NO)"
sleep 0.5
echo "Firewall: Porta 21 aberta"
sleep 0.5
echo "SELinux: Configurado para permitir escrita em /home/userftp/ftp/upload"
sleep 0.5
echo "Recomenda-se um reboot do sistema para garantir que todas as alterações tenham efeito."
echo "Para reiniciar o sistema, execute: reboot"
sleep 0.5

# reboot - Caso queira reiniciar automaticamente, descomente esta linha.

#============================================================================================================#

# GLOSSÁRIO

# $ # O que faz: Denota uma variável. Quando colocas $ antes de um nome, o Bash substitui o nome pelo valor que a variável armazena. Por exemplo, $IP_SERVIDOR é substituído pelo IP que o utilizador inseriu.

# #! /bin/bash # O que faz: Indica que o script deve ser executado usando o interpretador Bash.

# sudo # O que faz: Executa comandos com privilégios de superutilizador (root).

# dnf # O que faz: Gerenciador de pacotes para distribuições baseadas em RPM, como Fedora e CentOS.

# systemctl # O que faz: Ferramenta para controlar o sistema e serviços (systemd).

# firewall-cmd # O que faz: Ferramenta para configurar a firewall dinâmica do firewalld.

# tee # O que faz: Lê da entrada padrão e grava em arquivos, além de exibir na saída padrão.

# <<'CONF' ... CONF # O que faz: Redireciona um bloco de texto (aqui chamado CONF) para a entrada padrão de um comando (neste caso, o tee).

# id # O que faz: Verifica se um utilizador existe no sistema.

# useradd # O que faz: Cria um novo utilizador no sistema.

# chpasswd # O que faz: Define ou altera a senha de um utilizador.

# mkdir -p # O que faz: Cria diretórios, incluindo diretórios pai conforme necessário.

# chown # O que faz: Altera o proprietário e grupo de arquivos ou diretórios.

# chmod # O que faz: Altera as permissões de arquivos ou diretórios.

# grep -q # O que faz: Pesquisa silenciosamente por um padrão em um arquivo (sem saída).

# tee -a # O que faz: Anexa a saída a um arquivo em vez de sobrescrevê-lo.

# semanage # O que faz: Ferramenta para gerenciar políticas do SELinux.

# restorecon # O que faz: Restaura os contextos de segurança do SELinux em arquivos e diretórios.

# enable --now # O que faz: Ativa um serviço para iniciar automaticamente na inicialização e inicia-o imediatamente.

# restart # O que faz: Reinicia um serviço.

# sleep 1 # O que faz: Pausa a execução do script por 1 segundo.

# if ! id userftp &>/dev/null; then ... fi # O que faz: Verifica se o utilizador userftp existe; se não existir, cria-o.

# grep -qxF '/usr/sbin/nologin' /etc/shells || echo '/usr/sbin/nologin' | sudo tee -a /etc/shells >/dev/null

# O que faz: Verifica se /usr/sbin/nologin está em /etc/shells; se não estiver, adiciona-o.

# install -d -m 0555 -o root -g root /home/userftp/ftp
# O que faz: Cria o diretório /home/userftp/ftp com permissões 0555, proprietário root e grupo root.

# install -d -m 0733 -o userftp -g userftp /home/userftp/ftp/upload
# O que faz: Cria o diretório /home/userftp/ftp/upload com permissões 0733, proprietário userftp e grupo userftp.

# install -d -m 0555 -o userftp -g userftp /home/userftp/ftp/download
# O que faz: Cria o diretório /home/userftp/ftp/download com permissões 0555, proprietário userftp e grupo userftp.

# semanage fcontext -a -t public_content_rw_t "/home/userftp/ftp/{upload,download}(/.*)?"
# O que faz: Adiciona uma regra ao SELinux para permitir leitura e escrita nos diretórios upload e download.

# restorecon -Rv /home/userftp/ftp
# O que faz: Restaura os contextos de segurança do SELinux recursivamente no diretório /home/userftp/ftp.

# touch /etc/vsftpd/user_list
# O que faz: Cria o arquivo /etc/vsftpd/user_list se não existir.

# grep -q "^userftp$" /etc/vsftpd/user_list 2>/dev/null
# O que faz: Verifica silenciosamente se o utilizador userftp está na lista de utilizadores permitidos.

# echo "userftp" | sudo tee -a /etc/vsftpd/user_list >/dev/null
# O que faz: Adiciona o utilizador userftp ao arquivo user_list.

# systemctl enable --now vsftpd
# O que faz: Ativa o serviço vsftpd para iniciar automaticamente na inicialização e inicia-o imediatamente.

# systemctl restart vsftpd
# O que faz: Reinicia o serviço vsftpd para aplicar as novas configurações.

#============================================================================================================#
