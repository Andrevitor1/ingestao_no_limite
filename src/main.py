import os
import glob
import zipfile
import polars as pl

S3_ENDPOINT = os.getenv("S3_ENDPOINT", "http://localhost:9000")
BUCKET_TARGET = "s3://marketing-leads/silver_empresas"

print("--> [DESAFIO INGESTÃO] Processando arquivos reais da Receita Federal...")

# Leitura dinâmica de todos os zips na pasta /data/
df = pl.read_csv(
    "/data/*.zip",
    separator=";",
    has_header=False,
    encoding="iso-8859-1",
    new_columns=[
        "cnpj_basico", "razao_social", "natureza_juridica", 
        "qualificacao_responsavel", "capital_social", "porte_codigo", "ente_federativo"
    ]
)

# Transformações e tratamentos das Regras de Negócio
df = df.with_columns([
    pl.col("cnpj_basico").cast(pl.Utf8).str.zfill(8),
    pl.col("razao_social").str.to_uppercase().str.strip_chars(),
    pl.col("natureza_juridica").cast(pl.Utf8),
    pl.col("qualificacao_responsavel").cast(pl.Utf8),
    pl.col("capital_social").str.replace(",", ".").cast(pl.Float64),
    pl.col("porte_codigo").cast(pl.Utf8),
    pl.when(pl.col("porte_codigo") == "00").then(pl.lit("NÃO INFORMADO"))
      .when(pl.col("porte_codigo") == "01").then(pl.lit("MICRO EMPRESA"))
      .when(pl.col("porte_codigo") == "03").then(pl.lit("EMPRESA DE PEQUENO PORTE"))
      .otherwise(pl.lit("DEMAIS")).alias("porte_descricao"),
    pl.when(pl.col("ente_federativo") == "").then(None).otherwise(pl.col("ente_federativo")).alias("ente_federativo")
])

# Filtros B2B de Marketing
df = df.filter(
    (pl.col("capital_social") > 1000.0) & 
    (~pl.col("razao_social").str.contains(r"\d{11}$"))
)

# Gravação na camada Silver do MinIO
storage_options = {
    "aws_access_key_id": "admin",
    "aws_secret_access_key": "minio_password",
    "aws_endpoint_url": S3_ENDPOINT,
    "aws_allow_http": "true",
}

df.write_delta(BUCKET_TARGET, mode="overwrite", storage_options=storage_options)
print("--> Processamento concluído e salvo no MinIO com sucesso!")
