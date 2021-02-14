# Implementação de Pipeline para Processamento de Dados no AWS #

![alt text](https://github.com/lucasvieirademiranda/terraform/tree/main/images/archtecture.jpg)

Utiliza um CloudWatch que dispara a cada 5 minutos uma função lambda (data_load_lambda.py) que coleta dados da [PUNK API](https://api.punkapi.com/v2/beers/random) para alimentar um Kinesis Stream

Utiliza um Firehose (Raw Stream) agregando todas as entradas para guardar em um bucket S3 com o nome raw

Utiliza um Firehose (Cleaned Stream) chamando a função lambda (sanitize_lambda.py) que pega somente os campos id, name, abv, ibu, target_fg, target_og, ebc, srm e ph das cervejas

# Executando #

1º) Acesse o site do [Terraform](https://www.terraform.io/) e execute a instalação do mesmo;

2º) Abra o arquivo main.tf presente no diretório do projeto, e altere as linhas:

access_key = "AKIAJS6TJ7SSUFHWAQOGA"
secret_key = "A0BPdvlxH9coMSBBQcGtzayoDO4Mh4W/atBCERvD2"

Para incluir a sua chave do AWS.

3º) Através da linha de comando, estando no diretório do projeto, execute:
terraform apply