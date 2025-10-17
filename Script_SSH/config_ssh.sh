#!/bin/bash

#
# =========================================================================================#
#
# Projeto: Configuração de Servidor SSH em CentOS
# Autor: Sérgio Correia / Daniel Santos / Martinho Marques
# Data: 27 09 2025
#
# Descrição:
# Este script automatiza a instalação e configuração do serviço SSH em um sistema CentOS.
#
# =========================================================================================#
#

# O set -e é um comando a correr em Scripts para que este pare a execução
# se houver algum erro em qualquer comando.

# O que faz o -e: Faz com que o script termine imediatamente se qualquer comando retornar um código de saída diferente de zero (indicando um erro).

set -e

# O que faz o chmod 700: Define permissões de leitura, escrita e execução apenas para o proprietário do arquivo, garantindo que outros usuários não possam acessar ou modificar o script.

chmod 700 config_ssh.sh

# 1 - Instalação e Ativação do Serviço SSH
# O que faz: Instala o pacote openssh-server, inicia o serviço sshd e garante que este arranca automaticamente no boot.

# O que faz o -y: Responde automaticamente "sim" a todas as perguntas durante a instalação, permitindo que o processo seja não interativo.

sudo yum install -y openssh-server
sudo systemctl start sshd
sudo systemctl enable sshd

echo "Instalado o serviço openssh-server."
sleep 1

# 2 - Configuração da Firewall
# O que faz: Abre, permanentemente, a porta de serviço SSH na firewall(d) e aplica as alterações com --reload.

# O que faz o --permanent: Torna a regra permanente, sobrevivendo a reinícios.
# O que faz o --add-service=ssh: Adiciona o serviço SSH (porta 22) à lista de serviços permitidos.

sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload

echo "Permitido serviço de forma permanente na firewall."
sleep 1

# 3 - Criação de um backup
# O que faz: Cria uma cópia de segurança do ficheiro sshd.conf

# O que faz o cp: Copia arquivos ou diretórios de um local para outro.

sudo cp /etc/ssh/sshd_config "$HOME/sshd_config_backup"
echo "ssh_config copiado com sucesso para home."
sleep 1

# 4 - Configuração do sshd_conf
# O que faz: Edita, automaticamente, o ficheiro de configuração SSH para aplicar as definições apontadas.

# O que faz o -i do sed: Edita o arquivo no local, substituindo o conteúdo diretamente no arquivo original.

sudo sed -i 's,#Port 22,Port 22,' /etc/ssh/sshd_config
echo "Port alterada para 22."
sleep 0.5

sudo sed -i 's,#PermitRootLogin prohibit-password,PermitRootLogin prohibit-password,' /etc/ssh/sshd_config
echo "Desabilitado o Login de root com senha."
sleep 0.5

sudo sed -i 's,#MaxSessions 10,MaxSessions 10,' /etc/ssh/sshd_config
echo "Alterado o máximo de sessões em simultâneo."
sleep 0.5

sudo sed -i 's,#PasswordAuthentication yes,PasswordAuthentication yes,' /etc/ssh/sshd_config
echo "Desabilitado a autenticação por senha."
sleep 0.5

sudo sed -i 's,#PermitEmptyPassword,PermitEmptyPassword,' /etc/ssh/sshd_config
echo "Desabilitado a autentificação com senhas vazias."
sleep 0.5

sudo sed -i 's,#PubkeyAuthentication yes,PubkeyAuthentication yes,' /etc/ssh/sshd_config
echo "Habilitada a autenticação por chave pública."
sleep 0.5

sudo sed -i 's,^#\?AuthorizedKeysFile.*$,AuthorizedKeysFile .ssh/authorized_keys,' /etc/ssh/sshd_config
echo "Mudada a definição de arquivo de chaves públicas autorizadas."
sleep 0.5

# 5 - Aplicar as alterações
# O que faz: Reinicia o sshd.

sudo systemctl reload sshd

echo "Alterada a configuração final de sshd_config e faz reboot de seguida."

# 6 - Criação e atualização de permissões.
# O que faz: Cria a pasta .ssh e atualiza as permissões deste.

# O que faz o -p do mkdir: Cria diretórios pai conforme necessário, sem gerar erro se o diretório já existir.

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
echo "Criação da pasta .ssh e atualização das permissões de tal."

# 7 - Criação das RSA Keys
# O que faz: Gera, automaticamente, um par de chaves, privada e pública, no diretório $HOME.

# O que faz o -t rsa: Especifica o tipo de chave a ser gerada, neste caso RSA.
# O que faz o -f "$HOME/.ssh/id_rsa": Define o caminho e nome do arquivo onde a chave privada será salva.
# O que faz o -q: Executa o comando em modo silencioso, suprimindo a saída padrão.

echo "A criar Chaves RSA ..."
sudo ssh-keygen -t rsa -f "$HOME/.ssh/id_rsa" -q
echo "Chaves criadas em ~/.ssh/id_rsa.pub ."

# 8 - Configuração da chave pública para login.
# O que faz: Adiciona a chave pública ao ficheiro authorized_keys.

# O que faz o >>: Anexa a saída ao final do arquivo, em vez de sobrescrevê-lo.

cat "$HOME/.ssh/id_rsa.pub" >> "$HOME/.ssh/authorized_keys"
echo "Adicionada a chave pública ao authorized_keys."

# 9 - Atualização das permissões de acesso.
# O que faz: Define as permissões corretas para a pasta .ssh e authorized_keys

#O que faz o chmod 600: Define permissões de leitura e escrita apenas para o proprietário do arquivo, garantindo que outros usuários não possam acessar ou modificar o arquivo.

chmod 600 "$HOME/.ssh/authorized_keys"
echo "authorized_keys atualizado e permissões aplicadas."

# 10 - Reload do Serviço
# O que faz: Faz reload do serviço e mostra, de novo, o status.

sudo systemctl reload sshd
sudo systemctl status sshd
echo "Feito o reload do serviço."

# 11 - Mensagem Final
# O que faz: Informa o utilizador que o script terminou e recomenda um reboot do sistema.

echo "Recomenda-se um reboot do sistema para garantir que todas as alterações tenham efeito."
echo "Para reiniciar o sistema, execute: reboot"
sleep 0.5

#reboot - Caso queira reiniciar automaticamente, descomente esta linha.