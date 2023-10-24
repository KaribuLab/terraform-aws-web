# Terraform - AWS Web Module

## Uso

### Input

| Parámetro             | Tipo         | Descripción                                                                                                                                                         | Requerido |
| --------------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| tag_project_name      | string       | Nombre del proyecto                                                                                                                                                 | Si        |
| tag_customer_name     | string       | Nombre del cliente                                                                                                                                                  | Si        |
| tag_team_name         | string       | Nombre del equipo asociado al proyecto                                                                                                                              | Si        |
| tag_environment       | string       | Ambiente asociado a los recursos                                                                                                                                    | Si        |
| frontend_distribution | list(object) | Lista de distribuciones que deberán ser creadas, buckets CDN y APIs que deberán ser incluidas                                                                       | No        |
| default_s3_origin     | string       | Nombre del bucket de S3 usado como origen por defecto, en caso de no usarse se tomarán los valores de [`s3_origin`](#frontend_distribution) como origen por defecto | No        |

> NOTA: Debe existir al menos `frontend_distribution`, si no hay `default_s3_origin`

#### frontend_distribution

| Campo                                       | Tipo         | Descripción                                                                                                               | Requirido |
| ------------------------------------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------- | --------- |
| s3_orign                                    | string       | Origen usado como CDN u Origen por defecto de la distribución                                                             | Si        |
| behavior_patterns                           | list(string) | Patrones usados en el caso de que se use `s3_origin` como CDN                                                             | Si        |
| [api_gateway_origins](#api_gateway_origins) | list(object) | Objeto que contiene los parámetros usados para asociar recursos de API Gateway como *"Cache Behavior"* de la distribución | Si        |

#### api_gateway_origins

| Campo        | Tipo         | Descripción                                                                                                  | Requirido |
| ------------ | ------------ | ------------------------------------------------------------------------------------------------------------ | --------- |
| domain_name  | string       | Dominio autogenerado para API Gateway                                                                        | Si        |
| path_pattern | string       | Patrón para mapear peticiones de CloudFront con recurso de API Gateway                                       | Si        |
| origin_id    | string       | ID del origen asociado al API Gateway                                                                        | Si        |
| headers      | list(string) | Lista de headers que deben llegar al recurso del API Gateway (Los que no estén en esta lista serán omitidos) | Si        |
| cookies      | list(string) | Lista de cookies que deben llegar al recurso del API Gateway (Las que no estén en esta lista serán omitidas) | Si        |

### Output

## Desarrollo

### Requisitos

- Terraform versión 0.12 o superior
- AWS CLI 1.2 o superior
- Credenciales de AWS CLI

### Pruebas

Para probar el módulo de forma local, se deben crear 2 archivos:

`terraform.tfvars` y `.env` como se muestra a continuación:

```terraform
# Archivo terraform.tfvars
tag_project_name  = "Karibu Dev"
tag_customer_name = "Karibu"
tag_team_name     = "Área Creación"
tag_environment   = "production"
default_s3_origin = "krb-web"
frontend_distribution = [{
  s3_origin = "krb-cdn"
  behavior_patterns = [
    "css/*",
    "img/*"
  ],
  api_gateway_origins = [
    {
      domain_name  = "mabbwctzzr.execute-api.us-east-1.amazonaws.com"
      path_pattern = "site"
      origin_id    = "krb-api"
      headers = [
        "x-api-key"
      ]
      cookies = []
    }
  ]
}]

```

```shell
# Archivo .env
export AWS_SECRET_ACCESS_KEY=C9xhhXCcY4g7LJYUyXvztdVTE7tjvtXL6JsenjTb
export AWS_ACCESS_KEY_ID=LSDRWKXCQPHQJFDMXGYK
export AWS_DEFAULT_REGION=us-east-1
```

Luego para ejecutar el modulo deberá cargar las variables de ambiente de AWS usando el siguiente comando:

```shell
. .env
```

Posteriormente deberá inicializar el módulo, cargar el plan de ejecución y aplicar las instrucciones del módulo:

> **IMPORTANTE:** El `bucket` proporcionado en el parámetro `-backend-config` debe existir antes de ejecutar estos comandos.
> En este bucket se almacenará el estado del módulo de terraform.

```shell
terraform init -backend-config="bucket=krb-terraform-backend" -backend-config="key=terraform"
terraform plan
terraform apply
```

> En el último paso deberá confirmar si desea aplicar los cambios

Para destruir la infraestructura creada ejecute el comando `terraform destroy` y por último apruebe la ejecución.
