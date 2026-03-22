
#property copyright "Copyright 2024, theSiliconCoder."
#property link      "https://www.mq5.com"
#property version   "1.00"

string   address = "localhost";
int      port = 8104;

int socket;
bool closed = false;

int barsTotal;

short SYS_OK = 0;
short SYS_ERROR = -1;


#include <JAson.mqh>
CJAVal jv;

// trade data
#include <trade/trade.mqh>
#include <Trade\AccountInfo.mqh>
double lotSize = 4;
CTrade trade;
CAccountInfo acct;

void OnInit() {

   barsTotal = Bars(_Symbol,PERIOD_H1);
   
   //InitSocket();
   
   ReadFile(); // load predictions from disk
   
   
}


void InitSocket()
{
   // Initializing the socket
   socket = SocketCreate();
   if (socket == INVALID_HANDLE) Print("Error - 1: SocketCreate failure. ", GetLastError());
   else {
      if (SocketConnect(socket, address, port, 10000)) Print("[INFO]\tConnection Established with ML Server");
      else Print("Error - 2: SocketConnect failure. ", GetLastError());
   }
}


void OnTick()
{

   int bars = Bars(_Symbol, PERIOD_H1);
   
   // on each new bar, monitor chart for breakout
   if(barsTotal != bars)
     {

      barsTotal = bars; // update barsTotal with newly drawn bar/candle

      datetime timeToPredict = iTime(_Symbol, PERIOD_H1, 0);
      
      Print("Time Attr of Current Bar: ", timeToPredict);
      
      
      short pred = GetPredictionFromDisk(timeToPredict, 500);
      
      if (pred > 0) 
      {
      
         // liquidate short position if any
         closeAllSellOrdersandPositions();
         
         datetime orderDelay = TimeCurrent() + 2 ;
         
         //while (orderDelay > TimeCurrent())
         //{}
         
         double lotExpansion = MathFloor((acct.Balance() / 10000));
         
         lotSize = 4 + (lotExpansion - 1);
         
         Comment("\nBalance: ", acct.Balance(),"\n",
           "\nLotExpansion: ", lotExpansion,"\n",
           "\nlotSize: ", lotSize,"\n"
          );
      
         // go long or retain long position 
         if(OrdersTotal() == 0 && PositionsTotal()==0)
         {
          double cndlOpen = iOpen(_Symbol,PERIOD_H1,0);
          datetime expiryTime = TimeCurrent() + 10000; 
          //trade.BuyLimit(lotSize, cndlOpen + (50 * _Point), _Symbol, 0, 0, ORDER_TIME_SPECIFIED, expiryTime );
          trade.BuyLimit(lotSize, cndlOpen, _Symbol, 0, 0, ORDER_TIME_SPECIFIED, expiryTime );
          //trade.Buy(lotSize,_Symbol, SymbolInfoDouble(_Symbol,SYMBOL_ASK));
         }
      }
      
      else if (pred < 0) {
      
         // liquidate long positions if any
        closeAllBuyOrdersandPositions();
        
        datetime orderDelay = TimeCurrent() + 2 ;
         
         //while (orderDelay > TimeCurrent())
         //{}
         
         double lotExpansion = MathFloor((acct.Balance() / 10000));
         
         lotSize = 4 + (lotExpansion - 1);
         
         Comment("\nBalance: ", acct.Balance(),"\n",
           "\nLotExpansion: ", lotExpansion,"\n",
           "\nlotSize: ", lotSize,"\n"
          );
        
        // go short or retain short position
         
        if(OrdersTotal() == 0 && PositionsTotal()==0)
         {
          double cndlOpen = iOpen(_Symbol,PERIOD_H1,0);
          datetime expiryTime = TimeCurrent() + 10000; 
          //trade.BuyLimit(lotSize, cndlOpen + (50 * _Point), _Symbol, 0, 0, ORDER_TIME_SPECIFIED, expiryTime );
          trade.SellLimit(lotSize, cndlOpen, _Symbol, 0, 0, ORDER_TIME_SPECIFIED, expiryTime );
          //trade.Buy(lotSize,_Symbol, SymbolInfoDouble(_Symbol,SYMBOL_ASK));
         }
         
        
      }
      
      else {
         // do nothing
      }
      
     }


}

long GetPredictionFromServer(datetime timeToPredict, uint timeout)
{


   jv["client_id"]="qubitFXBot";
   //jv["time_to_predict"]="2023-03-24 16:00:00"; 
   jv["time_to_predict"]=TimeToString(timeToPredict);
   jv["password"]="Pass"; 
   
   //--- serialize to string  {"time_to_predict":"2023-03-24 16:00:00"}
   char data[]; 
   int data_len = StringToCharArray(jv.Serialize(), data, 0, WHOLE_ARRAY)-1;
   
   //--- send data
   Print("[INFO]\tSending Request to Server");
   SocketSend(socket, data, data_len);
   
   //--- read response
   char rsp[];
   string result;
   uint   timeout_check=GetTickCount()+timeout;
   
   do {
      
      uint len=SocketIsReadable(socket);
      
      //Print("[INFO]\tSocketIsReadable Len: ", len);
   
      if(len>5)
        {
         int rsp_len;
         
         Print("[INFO]\tReading Server Response");
         rsp_len=SocketRead(socket,rsp,len,timeout);
         Print("[INFO]\tSocketRead rsp_len: ", rsp_len);
         //--- analyze the response
         if(rsp_len>0)
           {
            result+=CharArrayToString(rsp,0,rsp_len);
            Print("[INFO]\tServer Response: ", result);
            
            
            //--- assume the answer {"accessToken":"ABRAKADABRA","session_id":124521}
            //--- get json obj values
            
            jv.Deserialize(rsp);
            string time_predicted=jv["time_predicted"].ToStr();
            int prediction=jv["prediction"].ToInt();
            
            Print("[INFO]\tML Server Prediction Result");
            Print("[INFO]\tTime Predicted: ", time_predicted);
            Print("[INFO]\tPrediction: ", prediction);
            
            // closeSocket();
            return (prediction);
           }
           
         }
   }
   
   while(GetTickCount()<timeout_check && !IsStopped());
   
   return (0);


}


void closeSocket()
{
   //if (!closed) {
         // Creating the message
       
         char req[];
         int len = StringToCharArray("END", req)-1;
         
         Print("[INFO]\tClosing Socket WITH: ", CharArrayToString(req));

         SocketSend(socket, req, len);
          
         //SocketClose(socket);
         closed = true;
     // }
}



short GetPredictionFromDisk(datetime timeToPredict, uint timeout)
{
   // {"2023.03.27 00:00:00":1}
   // short prediction=jv[TimeToString(timeToPredict)].ToInt();
   
   //Print("[INFO]\ttimeToPredict: ", TimeToString(timeToPredict, TIME_DATE | TIME_SECONDS));
   
   string timeKey = TimeToString(timeToPredict, TIME_DATE | TIME_SECONDS);
   
   short prediction=jv[timeKey].ToInt();
   
   Print("[INFO]\tML Server Prediction Result");
   Print("[INFO]\tTime Predicted: ", timeKey);
   Print("[INFO]\tPrediction: ", prediction);
   
   return (prediction);
   
}

void closeAllBuyOrdersandPositions()
  {
   if(OrdersTotal() > 0)
     {
      ulong currOrder = OrderGetTicket(0);
      
      if (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT)
      
      {
         trade.OrderDelete(currOrder);
      }
      
     }


   if(PositionsTotal() > 0)
     {

      ulong currPos = PositionGetTicket(0);

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {

         trade.PositionClose(currPos); // close position

        }

     }
  }
  
  
void closeAllSellOrdersandPositions()
  {
   if(OrdersTotal() > 0)
     {
      ulong currOrder = OrderGetTicket(0);
      
      if (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT)
      
      {
         trade.OrderDelete(currOrder);
      }
      
     }


   if(PositionsTotal() > 0)
     {

      ulong currPos = PositionGetTicket(0);

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {

         trade.PositionClose(currPos); // close position

        }

     }
  }


//+------------------------------------------------------------------+ 
//| Expert deinitialization function                                 | 
//+------------------------------------------------------------------+ 
void OnDeinit(const int reason) 
  { 
  
//--- The first way to get a deinitialization reason code 
   Print(__FUNCTION__," Deinitialization reason code = ",reason); 
//--- The second way to get a deinitialization reason code 
   Print(__FUNCTION__," _UninitReason = ",getUninitReasonText(_UninitReason)); 
//--- The third way to get a deinitialization reason code   
   Print(__FUNCTION__," UninitializeReason() = ",getUninitReasonText(UninitializeReason())); 
  } 
//+------------------------------------------------------------------+ 
//| Return a textual description of the deinitialization reason code | 
//+------------------------------------------------------------------+ 
string getUninitReasonText(int reasonCode) 
  { 
   string text=""; 
//--- 
   switch(reasonCode) 
     { 
      case REASON_ACCOUNT: 
         text="Account was changed";break; 
      case REASON_CHARTCHANGE: 
         text="Symbol or timeframe was changed";break; 
      case REASON_CHARTCLOSE: 
         text="Chart was closed";break; 
      case REASON_PARAMETERS: 
         text="Input-parameter was changed";break; 
      case REASON_RECOMPILE: 
         text="Program "+__FILE__+" was recompiled";break; 
      case REASON_REMOVE: 
         text="Program "+__FILE__+" was removed from chart";break; 
      case REASON_TEMPLATE: 
         text="New template was applied to chart";break; 
      default:text="Another reason"; 
     } 
//--- 
   return text; 
  }
  




//+------------------------------------------------------------------+ 
//| Script program start function                                    | 
//+------------------------------------------------------------------+ 
short ReadFile() 
  { 
  
   string InpFileName="predictions.txt"; // file name 
   string InpDirectoryName="C:/Users/theSiliconCoder/ml-forex"; // directory name 
//--- open the file 
   ResetLastError(); 
   //int file_handle=FileOpen(InpDirectoryName+"//"+InpFileName,FILE_READ|FILE_BIN|FILE_ANSI); 
   int file_handle=FileOpen(InpFileName,FILE_READ|FILE_ANSI|FILE_COMMON); 
   if(file_handle!=INVALID_HANDLE) 
     { 
      PrintFormat("%s file is available for reading",InpFileName); 
      PrintFormat("File path: %s\\Files\\",TerminalInfoString(TERMINAL_DATA_PATH)); 
      
      //--- additional variables 
      int    str_size; 
      string str; 
      
      //--- read data from the file 
      while(!FileIsEnding(file_handle)) 
        { 
         //--- find out how many symbols are used for writing the time 
         str_size=FileReadInteger(file_handle,INT_VALUE); 
         //--- read the string 
         str=FileReadString(file_handle,str_size); 
         
         //--- print the string 
         PrintFormat(str); 
         Print("File Content: ", str);
         
        } 
        
      jv.Deserialize(str);
      
      //--- close the file 
      FileClose(file_handle); 
      PrintFormat("Data is read, %s file is closed",InpFileName); 
      
      return SYS_OK;
     } 
   else 
      PrintFormat("Failed to open %s file, Error code = %d",InpFileName,GetLastError()); 
      
      return SYS_ERROR;
  }
  

