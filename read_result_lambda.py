from http.client import HTTPException

import boto3
import logging


def lambda_handler(event, context):
    uuid = event.get('uuid')
    logging.info(uuid)
    return get_table_item(uuid)


def get_table_item(item):
    table_name = "occurrences_table"
    session = boto3.Session(region_name='us-east-1')
    table = session.resource('dynamodb').Table(table_name)

    table_item = table.get_item(Key=item)
    if 'Item' in table_item:
        return table_item['Item']
    else:
        error = f'unable to find item in {table_name}'
        logging.exception(error)
        raise HTTPException(error)
