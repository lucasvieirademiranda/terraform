import json
import boto3
import urllib3

def handler(event, context):

    try:

        stream_name = "data_load_stream"
        url = "https://api.punkapi.com/v2/beers/random"

        http = urllib3.PoolManager(timeout = 30)

        response = http.request("GET", url)

        if (response.status != 200):
            raise Exception('Status should be 200.')

        result = response.data.decode("utf-8")

        client = boto3.client("kinesis")

        output = client.put_record(StreamName = stream_name, Data = result, PartitionKey = "partitionKey")

        print("SUCCESS")
        
    except Exception as e:

        print(e)