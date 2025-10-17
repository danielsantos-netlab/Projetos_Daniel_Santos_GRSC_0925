# ProjetoFinal_Linux
Criação de Scripts de DHCP, FTP e SSH

# Scripts Shell

Este repositório contém uma coleção de scripts em Shell que criámos para automatizar tarefas e resolver problemas comuns.

## Scripts Disponíveis

- `config_dhcp.sh`: Este script foi concebido para simplificar a configuração de um servidor DHCP em CentOS, operando em redes de Classe C com um CIDR /24. O programa valida os endereços IP inseridos pelo utilizador, configura automaticamente as interfaces de rede e os serviços necessários, e garante que a comunicação na rede é segura e funcional.
O objetivo é fornecer uma solução robusta e de fácil utilização para administradores de sistema.

- `config_ftp.sh`: Este script configura um servidor FTP usando vsftpd em modo ativo, cria um utilizador de demonstração, define diretórios isolados com permissões específicas e assegura que apenas utilizadores autorizados podem aceder ao servidor FTP.

- `config_ssh.sh`: Este script automatiza a instalação e configuração do serviço SSH em um sistema CentOS.

## Como Usar
Os Scripts estão ready-to-use, por isso basta fazer o download dos .sh e inserir dentro da Máquina Cliente. Juntamente com os Scripts, existem 2 manuais a seguir para realizar depois de correr os Scripts de SSH e FTP ( Instruções para SSH.pdf e Instruções para FTP.pdf ), pois os Clientes não conseguem aceder a este sem id_rsa.

1. Execute o script: `./nome_do_script.sh`
