# Terraform - AWS Web Module

## Uso

### Input

| Parámetro    | Tipo        | Descripción              | Requerido |
| ------------ | ----------- | ------------------------ | --------- |
| common_tags  | map(string) | Tags de los recursos     | Si        |
| distribution | object      | Datos de la distribución | Si        |

#### distribution

| Campo                                       | Tipo                   | Descripción                                                                                                               | Requirido |
| ------------------------------------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------- | --------- |
| s3_orign                                    | string                 | Origen usado como CDN u Origen por defecto de la distribución                                                             | Si        |
| description                                 | string                 | Descripción de la distribución                                                                                            | Si        |
| behavior_patterns                           | optional(list(string)) | Patrones usados en el caso de que se use `s3_origin` como CDN                                                             | No        |
| [api_gateway_origins](#api_gateway_origins) | optional(list(object)) | Objeto que contiene los parámetros usados para asociar recursos de API Gateway como *"Cache Behavior"* de la distribución | No        |

#### api_gateway_origins

| Campo        | Tipo         | Descripción                                                                                                  | Requirido |
| ------------ | ------------ | ------------------------------------------------------------------------------------------------------------ | --------- |
| domain_name  | string       | Dominio autogenerado para API Gateway                                                                        | Si        |
| path_pattern | string       | Patrón para mapear peticiones de CloudFront con recurso de API Gateway                                       | Si        |
| origin_id    | string       | ID del origen asociado al API Gateway                                                                        | Si        |
| origin_path  | string       | Ruta principal del origin                                                                                    | Si        |
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
common_tags = {
  "project" = "Hello World"
}

distribution = {
  description = "Hello World"
  s3_origin = "karibu-hello-world"
}
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

```shell
terraform init
terraform plan
terraform apply
```

> En el último paso deberá confirmar si desea aplicar los cambios

Para destruir la infraestructura creada ejecute el comando `terraform destroy` y por último apruebe la ejecución.
