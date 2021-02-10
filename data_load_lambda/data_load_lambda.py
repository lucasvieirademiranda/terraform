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

        data = json.loads(response.data.decode("utf-8"))[0]

        partitionKey = data['first_brewed']

        result = json.dumps(data)

        client = boto3.client("kinesis")

        output = client.put_record(StreamName = stream_name, Data = result, PartitionKey = partitionKey)

        print(result)
        print("SUCCESS")
        
    except Exception as e:

        print(e)