import json
from io import BytesIO

import boto3
import pandas as pd
import psycopg2
from sqlalchemy import create_engine

s3 = boto3.client('s3')
ssm = boto3.client('ssm')


def get_json_param(param_name: str) -> dict:
    response = ssm.get_parameter(
        Name=param_name,
        WithDecryption=True
    )
    config = response['Parameter']['Value']
    return json.loads(config)


def lambda_handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']

    obj = s3.get_object(Bucket=bucket, Key=key)
    df = pd.read_csv(BytesIO(obj["Body"].read()))

    config = get_json_param('/db_instance/credentials')

    host = config['host']
    port = config['port']
    dbname = config['dbname']
    user = config['user']
    password = config['password']

    create_db_table(host, dbname, user, password, port)

    engine = create_engine(
        f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{dbname}"
    )

    df.to_sql(
        name="muchen_auto",
        con=engine,
        if_exists="append",
        index=False
    )

    result = pd.read_sql("SELECT COUNT(*) AS n FROM muchen_auto", engine)
    print(f"No of Rows: {result['n'].iloc[0]}")


def create_db_table(host, dbname, user, password, port):
    conn = psycopg2.connect(
        host=host,
        dbname=dbname,
        user=user,
        password=password,
        port=port
    )
    cursor = conn.cursor()

    cursor.execute("""
        DROP TABLE muchen_auto;
    """)

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS muchen_auto (
            booking_id     TEXT,
            listing_id     TEXT,
            booking_date   DATE,
            nights_booked  BIGINT,
            booking_amount BIGINT,
            cleaning_fee   BIGINT,
            service_fee    BIGINT,
            booking_status TEXT,
            created_at     TIMESTAMP
        );
    """)
    conn.commit()
    cursor.close()
    conn.close()
