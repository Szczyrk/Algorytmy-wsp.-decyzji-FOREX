

#include <Roffild/ToIndicator.mqh>

//--- object for performing trade operations

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
      string pack[30];
     
      MqlDateTime stm;
      TimeToStruct(rt[0].time,stm);
      pack[0] = StringFormat("%4d.%02d.%02d;",stm.year, stm.mon, stm.day);
      pack[1] = StringFormat("%02d:%02d:%02d;",stm.hour, stm.min, stm.sec);
      pack[2] = DoubleToString(rt[0].tick_volume)+";";
      pack[3] = DoubleToString(rt[0].real_volume)+";";
      pack[4] = DoubleToString(rt[0].open)+";";
      pack[5] = DoubleToString(rt[0].close)+";";
      pack[6] = DoubleToString(rt[0].high)+";";
      pack[7] = DoubleToString(rt[0].low)+";";
      
      CopyBuffer(MA4_handle,0,0,4,MA4);
      CopyBuffer(MA12_handle,0,0,4,MA12);
      CopyBuffer(MA50_handle,0,0,4,MA50);
      CopyBuffer(MA200_handle,0,0,4,MA200);
      double ma4=MA4[0]; 
      double ma12=MA12[0];
      double ma50=MA50[0]; 
      double ma200=MA200[0]; 
      
      if(!CopyBufferAsSeries(SAR_handle,0,0,4,true,SAR)) return;
      for(int i=0;i<4;i++)
      {
         pack[22+i*2] = DoubleToString(SAR[i])+";";
         if(rt[0].close > SAR[i])
            pack[22+i*2+1] = "true;";
          else
            pack[22+i*2+1] = "false;";
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
      double priceChange;
      double ma4Change;
      double ma12Change;
      double ma50Change;
      double ma200Change;
      if(rt[3].close != 0)
         priceChange= (rt[0].close-rt[3].close)/rt[3].close*100;
       else
         priceChange=0;
      if(MA4[3] != 0)
         ma4Change = (MA4[0]-MA4[3])/MA4[3]*100;
        else
        ma4Change = 0;
      if(MA12[3] != 0)
         ma12Change = (MA12[0]-MA12[3])/MA12[3]*100;
      else
         ma12Change = 0;
      if(MA50[3] != 0)
          ma50Change= (MA50[0]-MA50[3])/MA50[3]*100;
          else
          ma50Change = 0;
      if(MA200[3] != 0)
         ma200Change = (MA200[0]-MA200[3])/MA200[3]*100;
      else
         ma200Change = 0;
    //  Print("priceChange" + priceChange);
      if(firstFourHour<4)
      {
         return;
      }
         pack[8] = DoubleToString(priceChange)+";";
         pack[9] = DoubleToString(priceChange * 100)+";";
         pack[10]=DoubleToString(ma4)+";";
         pack[11]=DoubleToString(ma4Change)+";";
         pack[12]=DoubleToString(ma4Change*100)+";";
         pack[13]=DoubleToString(ma12)+";";
         pack[14]=DoubleToString(ma12Change)+";";
         pack[15]=DoubleToString(ma12Change*100)+";";
         pack[16]=DoubleToString(ma50)+";";
         pack[17]=DoubleToString(ma50Change)+";";
         pack[18]=DoubleToString(ma50Change*100)+";";
         pack[19]=DoubleToString(ma200)+";";
         pack[20]=DoubleToString(ma200Change)+";";
         pack[21]=DoubleToString(ma200Change*100)+";";

      double result[1];
      int file_handle=FileOpen("eurousd_data.csv", FILE_READ|FILE_WRITE|FILE_COMMON);
   if(file_handle!=INVALID_HANDLE)
     {
      string tmp ="";
      for(int i =0; i<30;i++)
         tmp = tmp + pack[i];
      tmp = StringSubstr(tmp, 0, StringLen(tmp)-1);
      FileSeek(file_handle, 0, SEEK_END);
      FileWrite(file_handle,tmp);
      //--- close the file
      FileClose(file_handle);
     }
   else
      PrintFormat("Failed to open %s file, Error code = %d","eurousd_data",GetLastError());
        
      
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