import base64
import json

def handler (event, context):

    success = 0
    failure = 0

    output = []

    for record in event["records"]:

        decodedBytes = base64.b64decode(record['data'])
        decodedString = str(decodedBytes, 'utf-8')

        try:

            data = json.loads(decodedString)

            csv = "{id},{name},{abv},{ibu},{target_fg},{target_og},{ebc},{srm},{ph}".format(
                id = data['id'],
                name = data['name'],
                abv = data['abv'],
                ibu = data['ibu'],
                target_fg = data['target_fg'],
                target_og = data['target_og'],
                ebc = data['ebc'],
                srm = data['srm'],
                ph = data['ph']
            )

            encodedBytes = base64.b64encode(csv.encode("utf-8"))
            encodedString = encodedBytes.decode('utf-8')

            newRecord = {
                "recordId": record["recordId"],
                "result": "Ok",
                "data": encodedString
            }
                        
            output.append(newRecord)

            print('Success')
            success += 1

        except Exception as e:

            errorRecord = {
                "recordId": record['recordId'],
                "result": 'ProcessingFailed',
                "data": record["data"]
            }

            output.append(errorRecord)

            print('Failure')
            print(e)
            failure += 1
    
    summary = "Successes: {success}, Failures: {failure}".format(success = success, failure = failure)
    print(summary)

    return { "records" : output }



