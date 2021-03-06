-- UDF: Convert a Table into a XML Document
-- Parameters: ParSelect        --> SQL Select-Statement to be converted
--             ParRoot          --> Optional:  Name of the root element
--                                             Default = "rowset"
--             ParRow           --> Optional:  Name of the row element
--                                             Default = "row"
--             ParAsAttribute   --> Optional:  Y = a single empty element per row
--                                                 all column values are included as attributes
--*************************************************************************************************
Create or Replace Function SELECT2XML(
                           ParSelect        VARCHAR(32700),
                           ParRoot          VarChar(128)    Default '"rowset"',
                           ParRow           VarChar(128)    Default '"row"',
                           ParAsAttributes  VarChar(1)      Default '')
       Returns XML
       Language SQL
       Modifies SQL Data
       Specific SELECT2XML
       Not Fenced
       Not Deterministic
       Called On Null Input
       No External Action
       Not Secured

       Set Option Datfmt  = *Iso,
                  Dbgview = *Source,
                  Decmpt  = *COMMA,
                  DLYPRP  = *Yes,
                  Optlob  = *Yes,
                  SrtSeq  = *LangIdShr
   --==============================================================================================
   Begin
     Declare GblView            VarChar(257)   Default '';
     Declare GblViewName        VarChar(128)   Default '';
     Declare GblViewSchema      VarChar(128)   Default '';

     Declare GblSelectNoOrderBy VarChar(32700) Default '';
     Declare GblOrderBy         VarChar(1024)  Default '';

     Declare GblViewExists      SmallInt       Default 0;
     Declare GblPos             Integer        Default 0;
     Declare GblLastOrder       Integer        Default 0;
     Declare GblOccurence       Integer        Default 0;

     Declare RtnXML             XML;

     Declare Continue Handler for SQLSTATE '42704' Begin End;

     Declare Continue Handler for SQLException
             Begin
                Declare LocErrText VarChar(128) Default '';
                Get Diagnostics Condition 1 LocErrText = MESSAGE_TEXT;
                Execute Immediate 'Drop View ' concat GblView;
                Return XMLElement(Name "rowset",
                             XMLElement(Name "Error", LocErrText));
             End;
     ----------------------------------------------------------------------------------------------
     Set GblViewName   = Trim('SELECT2XML' concat
                              Trim(Replace(qsys2.Job_Name, '/', '')));

     Set GblViewSchema = Trim('QGPL');
     Set GblView       = GblViewSchema concat '.' concat GblViewName;

     If Trim(ParSelect) = ''
        Then Return XMLElement(Name "rowset",
                               XMLElement(Name "Error",
                                          'Select Statement not passed'));
     End If;

     --1. Find the last Order by in the SQL Statement (if any)
     --   --> Split SQL Statement into SELECT and ORDER BY
     StartLoop:
          Repeat set GblOccurence = GblOccurence + 1;
                 set GblPos = Locate_in_String(ParSelect,
                                               'ORDER BY', 1, GblOccurence);
                 If GblPos > 0
                    Then Set GblLastOrder = GblPos;
                 End If;
          Until GblPos = 0 End Repeat;

      If GblLastOrder > 0
         Then Set GblSelectNoOrderBy = Substr(ParSelect, 1, GblLastOrder - 1);
              Set GblOrderBy = Replace(Substr(ParSelect, GblLastOrder),
                                       'ORDER BY', '');
      Else Set GblSelectNoOrderBy = Trim(ParSelect);
           Set GblOrderBY         = '' ;
      End If;

      --2. Drop View if it already exists
      Select 1 into GblViewExists
        From SysTables
        Where     Table_Name   = GblViewName
              and Table_Schema = GblViewSchema
      Fetch First Row Only;

      If GblViewExists = 1
         Then Execute Immediate 'Drop View ' concat GblView;
      End If;

      --3. Create View
      Execute Immediate 'Create View '  concat GblView            concat
                                ' as (' concat GblSelectNoOrderBy concat ' )';

      --4. Generate XML Document (by calling TABLE2XML)
      Set RtnXML = Table2XML(GblViewName, GblViewSchema, '', GblOrderBy,
                             ParRoot,     ParRow,            ParAsAttributes);

      --5. Drop View
      Execute Immediate 'Drop View ' concat GblView;

      Return RtnXML;
   End;

Begin
  Declare Continue Handler For SQLEXCEPTION Begin End;
   Label On Specific Function SELECT2XML
      Is 'Convert a Select Statement into XML';

   Comment On Parameter Specific Routine SELECT2XML
     (PARSELECT        Is 'Select Statement',
      PARORDERBY       Is 'ORDER BY for sorting the output
                           without leading ORDER BY',
      PARRoot          Is 'Root element name --> Default "rowset"',
      PARRow           Is 'Row element name --> Default "row"',
      PARAsAttributes  Is 'Y = Return a single element per row
                               all column values are returned as attributes');
End;                                                                                                    
