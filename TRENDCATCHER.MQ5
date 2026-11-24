#include <Trade/Trade.mqh>
#property strict

input double lotSize     = 0.01;
input int    emaPeriod   = 9;
input double maxLossUSD  = 3.0;
input long   magicNumber = 1001;   // unique ID for this EA

CTrade trade;
datetime lastBarTime = 0;
int emaHandle;
int lastDirection = 0;              // 0 none, 1 buy, -1 sell

int OnInit()
{
   trade.SetExpertMagicNumber(magicNumber);

   emaHandle = iMA(_Symbol, PERIOD_M1, emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(emaHandle == INVALID_HANDLE)
   {
      Print("Failed to create EMA handle");
      return INIT_FAILED;
   }
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(emaHandle != INVALID_HANDLE)
      IndicatorRelease(emaHandle);
}

void CloseAllMyPositions()
{
   int total = PositionsTotal();
   for(int idx = total - 1; idx >= 0; idx--)
   {
      ulong ticket = PositionGetTicket(idx);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      long magic = (long)PositionGetInteger(POSITION_MAGIC);

      if(sym == _Symbol && magic == magicNumber)
      {
         trade.PositionClose(ticket);
         Sleep(50);
      }
   }
}

void CheckMyMaxLoss()
{
   int total = PositionsTotal();
   for(int idx = total - 1; idx >= 0; idx--)
   {
      ulong ticket = PositionGetTicket(idx);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      long magic = (long)PositionGetInteger(POSITION_MAGIC);

      if(sym == _Symbol && magic == magicNumber)
      {
         double profit = PositionGetDouble(POSITION_PROFIT);
         if(profit <= -maxLossUSD)
         {
            PrintFormat("Max loss reached for ticket %I64u. Closing.", ticket);
            trade.PositionClose(ticket);
            Sleep(50);
         }
      }
   }
}

void OnTick()
{
   CheckMyMaxLoss();

   datetime t = iTime(_Symbol, PERIOD_M1, 0);
   if(t == lastBarTime) return;
   lastBarTime = t;

   double emaBuf[];
   if(CopyBuffer(emaHandle, 0, 1, 1, emaBuf) <= 0)
   {
      Print("CopyBuffer EMA failed");
      return;
   }

   double emaValue   = emaBuf[0];
   double closePrice = iClose(_Symbol, PERIOD_M1, 1);

   // Flip to SELL (was BUY)
   if(closePrice > emaValue && lastDirection != -1)
   {
      CloseAllMyPositions();
      if(trade.Sell(lotSize, _Symbol))
      {
         PrintFormat("Sell opened (price > EMA) [magic=%d]", magicNumber);
         lastDirection = -1;
      }
   }
   // Flip to BUY (was SELL)
   else if(closePrice < emaValue && lastDirection != 1)
   {
      CloseAllMyPositions();
      if(trade.Buy(lotSize, _Symbol))
      {
         PrintFormat("Buy opened (price < EMA) [magic=%d]", magicNumber);
         lastDirection = 1;
      }
   }
}
