import pandas as pd
import socket
import json
import time





def get_prediction(time_to_predict):

    df = pd.read_csv('predictions.csv')
    df['Time'] = pd.to_datetime(df['Time'])
    df.set_index('Time', inplace=True)

    # print (df)

    time_to_predict = pd.to_datetime(time_to_predict)
    result = df[df.index == time_to_predict]

    result = result.Predicted.iloc[0]

    print(f"\nPrinting Result: {result}")

    return result

def process_request(client_payload):
        
    # parse req:
    request = json.loads(client_payload)

    time = request["time_to_predict"]
    server_action = request["action"]

    time = time.replace('.', '-')
 
    res = get_prediction(time)

    if (server_action == 'Update File'):
        populate_prediction_file()
    
    # print(f"server response: {res}")

    # print(f"server response: {get_prediction(time)}")

    response = {
      "time_predicted": time,
      "prediction": res
    }
    
    # convert into JSON:
    response = json.dumps(response)

    return response


def launch_server() -> int :
    serversocket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    
    print("[INFO]\tMachine Learning Server Up and Running!:", serversocket)
    
    serversocket.bind(("localhost", 8104))
    serversocket.listen(10)
    
    connection, addr = serversocket.accept()
    print("[INFO]\tConnection Established with Client:", addr)
    
    msg = ""
    while not "END" in msg:
        msg = connection.recv(1024).decode()
        if (len(msg) > 5):
            print("[INFO]\tRequest Recvd:", msg)
            response = process_request(msg) 
            print("[INFO]\tResponse Ready:: ", response)
            # time.sleep(2)
            connection.send(response.encode('utf-8'))
        elif (len(msg)):
            print("[INFO]\tMessage Recvd:", msg)

    # msg = connection.recv(1024).decode()
    # print("[INFO]\tRequest Recvd:", msg)
    # response = process_request(msg) 
    # print("[INFO]\tResponse Ready:: ", response)
    
    # connection.send(response.encode('utf-8'))

    # time.sleep(2)
    
    connection.close()
    serversocket.close()
    print("Server closed!\n")

    return 0

def populate_prediction_file():

    df = pd.read_csv('predictions.csv')
    df['Time'] = df['Time'].str.replace('-', '.')
    
    df.set_index('Time', inplace=True)
    pred_dict = df['Predicted'].to_dict()

    json_txt = json.dumps(pred_dict)

    fpath = 'C:\\Users\\theSiliconCoder\\AppData\\Roaming\\MetaQuotes\\Terminal\\Common\\Files\\'
    filename = 'predictions.txt'
    final_path = fpath + filename
    
    file1 = open(final_path, 'w')
    # Writing a string to file
    file1.write(json_txt)

    print(f"\nPrinting File Contents: {json_txt}")

def main():
    
    launch_server()

if __name__ == "__main__":
    main()