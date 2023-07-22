import uuid
from http.client import HTTPException

import boto3
import logging


def lambda_handler(event, context):
    uu = uuid.uuid4().__str__()
    occurrences_json = get_occurrences(event, uu)
    logging.info(occurrences_json)
    logging.info(uu)
    put_item(occurrences_json)
    return uu


def put_item(json_item):
    try:
        table_name = "occurrences_table"
        session = boto3.Session(region_name='us-east-1')
        table = session.resource('dynamodb').Table(table_name)
        table.put_item(TableName=table_name, Item=json_item)
    except Exception as Error:
        logging.exception(Error)
        print(f"something went wrong with the dynamodb update, see error: \n {Error}")
        raise HTTPException(Error)


def get_occurrences(event, uu):
    string = event.get('string')
    char = event.get('char')
    occurrences = len([acc for acc in string if acc == char])
    return {uu: {"occurrences": occurrences}}
