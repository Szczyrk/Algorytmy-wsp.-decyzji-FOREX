/*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* https://github.com/Roffild/RoffildLibrary
*/
#property copyright "Roffild"
#property link      "https://github.com/Roffild/RoffildLibrary"

input string PythonHome = "";

#include <Roffild/PythonDLL.mqh>
#include <Roffild/ToIndicator.mqh>
#include<Trade\Trade.mqh>
//--- object for performing trade operations
CTrade  trade;

#resource "DL.py" as string _PyCode_
CPythonDLL python;
int        SAR_handle;
double      SAR[];   
double      MA4[];                // array for the indicator iMA
int         MA4_handle; 
double      MA12[];                // array for the indicator iMA
int         MA12_handle; 
double      MA50[];                // array for the indicator iMA
int         MA50_handle; 
double      MA200[];                // array for the indicator iMA
int         MA200_handle; 
CToIndicator indicMedian;

int OnInit()
{
   if (PythonHome == "") {
      Print("ERROR: PythonHome == \"\"");
      return INIT_FAILED;
   }
   if (python.initialize(PythonHome) == false) {
      Print("ERROR: Py_NewInterpreter() is not created.");
      return INIT_FAILED;
   }
   const string errinit = python.getErrorText();
   if (errinit != "") {
      Print(errinit);
      return INIT_FAILED;
   }
   if (python.eval(_PyCode_, true) == false) {
      return INIT_FAILED;
   }
   uchar array[];
   StringToCharArray("Version_info: ", array);
   Print(python.getString(1, "Version: ", array));
   Print(python.getString(2, "", array));
   Print(python.getString(3, "", array));
   Print("Error in Python:");
   python.getString(99, "", array);

   if (indicMedian.init("indicMedian") == INVALID_HANDLE) {
      Print("ERROR: indicMedian.init");
      return INIT_FAILED;
   }
   indicMedian.addPlot(DRAW_COLOR_LINE, "Median");
   indicMedian.plotIndexSetInteger(0, PLOT_LINE_WIDTH, 5);
   indicMedian.plotIndexSetInteger(0, PLOT_COLOR_INDEXES, 2);
   indicMedian.plotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrAquamarine);
   indicMedian.plotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrPink);

   indicMedian.show();
   SAR_handle=iSAR(NULL,0,0.02,0.2);
   MA4_handle=iMA(NULL,0,4,0,MODE_EMA,PRICE_CLOSE);
   MA12_handle=iMA(NULL,0,12,0,MODE_EMA,PRICE_CLOSE);
   MA50_handle=iMA(NULL,0,50,0,MODE_EMA,PRICE_CLOSE);
   MA200_handle=iMA(NULL,0,200,0,MODE_EMA,PRICE_CLOSE);
   //--- set MagicNumber for your orders identification
   int MagicNumber=123456;
   trade.SetExpertMagicNumber(MagicNumber);
//--- set available slippage in points when buying/selling
   int deviation=10;
   trade.SetDeviationInPoints(deviation);
//--- order filling mode, the mode allowed by the server should be used
   trade.SetTypeFilling(ORDER_FILLING_RETURN);
//--- logging mode: it would be better not to declare this method at all, the class will set the best mode on its own
   trade.LogLevel(1); 
//--- what function is to be used for trading: true - OrderSendAsync(), false - OrderSend()
   trade.SetAsyncMode(true);
   
   return INIT_SUCCEEDED;
}

void OnTick()
{
   static datetime LastHr=0;
   static int firstFourHour = 1;
   static int sar1 = 0;
   static int sar2 = 0;
   static int sar3 = 0;
   static int sar4 = 0;
   static double lastClose;
   datetime ThisHr=iTime(NULL,PERIOD_H1,0);
   if(LastHr!=ThisHr)
      {
      LastHr=ThisHr;
      
      //Print(TimeCurrent ());
      MqlRates rt[];
      CopyRates(Symbol(), Period(), 0, 4, rt);
      ArraySetAsSeries(rt, false);
      double pack[33];
    //  Print(sizeof(rt));
      for(int i=0;i<24;i++)
         pack[i] = 0;
      MqlDateTime stm;
      TimeToStruct(rt[0].time,stm);
      pack[stm.hour+2] = 1;
      CopyBuffer(MA4_handle,0,0,1,MA4);
      CopyBuffer(MA12_handle,0,0,1,MA12);
      CopyBuffer(MA50_handle,0,0,1,MA50);
      CopyBuffer(MA200_handle,0,0,1,MA200);
      double ma4=MA4[0]; 
      double ma12=MA12[0];
      double ma50=MA50[0]; 
      double ma200=MA200[0]; 
      
      if(!CopyBufferAsSeries(SAR_handle,0,0,4,true,SAR)) return;
      for(int i=0;i<4;i++)
      {
       //Print(SAR[i] + "  >  "+ rt[0].close);
         if(rt[0].close > SAR[i])
            SAR[i] = 1;
          else
            SAR[i] = 0;
       }

   /*   for(int i=0;i<6;i++)
      {
         
         pack[i] = rt[i].close;
         pack[i] = rt[i].open;
         pack[i] = rt[i].high;
         pack[i] = rt[i].low;
    */     
   //---
   /*      Print(rt[i].spread);
         Print(rt[i].real_volume);
         Print(rt[i].tick_volume);
         Print(sizeof(rt[i]));*/
      firstFourHour++;
      double priceChange = (rt[0].close-rt[3].close)/rt[3].close*100;
    //  Print("priceChange" + priceChange);
      if(firstFourHour<4)
      {
         return;
      }
      printf("PostioinTotal: " + PositionsTotal() + " Orders: " + OrdersTotal());
         if(PositionsTotal()>1) return;
         pack[24]=priceChange;
         pack[25]=SAR[0];
         pack[26]=SAR[1];
         pack[27]=SAR[2];
         pack[28]=SAR[3];
         pack[29]=ma4;
         pack[30]=ma12;
         pack[31]=ma50;
         pack[32]=ma200;
    /*   Print("");
         Print("State:");
         for(int i=0;i<33;i++)
            Print(pack[i]);
            
            Print("");*/
   
      double volume=0.1;
      string symbol=Symbol();    // specify the symbol, at which the order is placed
      int    digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   //--- point value
      double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   //--- receiving a buy price
   
      double price=SymbolInfoDouble(symbol,SYMBOL_ASK);
   //--- calculate and normalize SL and TP levels
      double SL=NormalizeDouble(price-500*point,digits);
      double TP=NormalizeDouble(price+500*point,digits);
   //--- filling comments
      string comment="Buy "+symbol+" 0.1 at "+DoubleToString(price,digits);
      double result[1];
      python.getDouble(33, 0, pack, result);
         Print("Result: " + result[0]);
      if(result[0] == 1)
      {
         if(!trade.PositionOpen(symbol,ORDER_TYPE_BUY,0.1,price,SL,TP,comment))
           {
            //--- failure message
           // Print("PositionOpen() method failed. Return code=",trade.ResultRetcode(),
            //      ". Code description: ",trade.ResultRetcodeDescription());
           }
         else
           {
           // Print("PositionOpen() method executed successfully. Return code=",trade.ResultRetcode(),
             //     " (",trade.ResultRetcodeDescription(),")");
           }
      }
      if(result[0] == 2)
      {
         if(!trade.PositionOpen(symbol,ORDER_TYPE_SELL,0.1,price,SL,TP,comment))
           {
            //--- failure message
            //Print("PositionOpen() method failed. Return code=",trade.ResultRetcode(),
              //    ". Code description: ",trade.ResultRetcodeDescription());
           }
         else
           {
           // Print("PositionOpen() method executed successfully. Return code=",trade.ResultRetcode(),
             //     " (",trade.ResultRetcodeDescription(),")");
           }
      }
      
   }
}

bool CopyBufferAsSeries(
                        int handle,      // indicator's handle
                        int bufer,       // buffer index
                        int start,       // start index
                        int number,      // number of elements to copy
                        bool asSeries,   // if it's true, the elements will be indexed as series
                        double &M[]      // target array
                        )
  {
//--- filling the array M with current values of the indicator
   if(CopyBuffer(handle,bufer,start,number,M)<=0) return(false);
//--- the elements will be indexed as follows:
//--- if asSeries=true, it will be indexed as timeseries
//--- if asSeries=false, it will be indexed as default
   ArraySetAsSeries(M,asSeries);
//---
   return(true);
  }