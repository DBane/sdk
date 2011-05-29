#include <stdarg.h>

public import "ecere"

public struct CSVFileParameters
{
   char fieldSeparator;
   char valueQuotes;
   int expectedFieldCount;
   bool tolerateNewLineInValues;
   //bool checkNulls;
   //bool checkCurlies;
};

CSVFileParameters classicParameters = { ',', '\"', 0, false };

public struct CSVFileState
{
   uint lineNum;
   uint charNum;
   uint rowNum;
   uint fieldNum;
};

public class CSVFile : public File
{
public:
   CSVFileParameters options;
   CSVFileState info;

   void PrintMessage(typed_object object, ...)
   {
      va_list args;
      char buffer[4096];
      va_start(args, object);
      PrintStdArgsToBuffer(buffer, sizeof(buffer), object, args);
      va_end(args);
      OnMessage(buffer);
   }

   virtual bool OnMessage(String message)
   {
      ::PrintLn(this._class.name, ": ", message,
            " lineNum=", info.lineNum,
            " charNum=", info.charNum,
            " rowNum=", info.rowNum,
            " fieldNum=", info.fieldNum);
   }

   virtual bool OnRowStrings(Array<String> strings);

   virtual void Process()
   {
      bool quoted = false, status = true;
      Array<String> values { };
      int start = 0, end = 0;
      int readCount = 0;
      Array<char> buffer { minAllocSize = 4096 };

      //info.charNum = 0;
      info.lineNum = 0;
      info.rowNum = 0;
      info.fieldNum = 0;

      while(!Eof() && status)
      {
         int c, offset = 0;

         if(start)
         {
            offset = readCount - start;
            if(offset > buffer.minAllocSize / 2)
               buffer.minAllocSize += 4096;
            memmove(&buffer[0], &buffer[start], offset);
            end -= start;
            start = 0;
         }

         readCount = offset + Read(&buffer[offset], 1, buffer.minAllocSize - offset);
         for(c = offset; c < readCount && status; c++)
         {
            char ch = buffer[c];
            if(quoted)
            {
               if(ch == options.valueQuotes)
               {
                  quoted = false;
                  end = c;
               }
            }
            else
            {
               if(ch == options.valueQuotes)
               {
                  quoted = true;
                  start = c + 1;
               }
               //else if(ch == options.fieldSeparator || ch == '\n')
               else if(ch == options.fieldSeparator ||
                     (ch == '\n' && (!options.tolerateNewLineInValues || info.fieldNum == options.expectedFieldCount-1)))
               {
                  int len = end-start;
                  String value = new char[len+1];
                  memcpy(value, &buffer[start], len);
                  value[len] = 0;
                  values.Add(value);
                  start = end = 0;
                  info.fieldNum++;
                  if(ch == '\n')
                  {
                     info.lineNum++;
                     info.rowNum++;
                     status = OnRowStrings(values);
                     values.Free();
                     //info.charNum = 0;
                     info.fieldNum = 0;
                  }
               }
               else if(ch == '\r');
               else
               {
                  if(!start)
                     start = c;
                  end = c;
               }
            }
            //info.charNum++;
         }
      }
      if(end > start)
      {
         int len = end-start;
         String value = new char[len+1];
         memcpy(value, &buffer[start], len);
         value[len] = 0;
         values.Add(value);
      }
      if(values.count && status)
      {
         status = OnRowStrings(values);
         info.rowNum++;
      }
      values.Free();
      delete values;
   }
}