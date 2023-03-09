%{
#include "y.tab.h"
void yyerror (char *s);
%}
%%
"storage\."	return STORAGE;
"receive"	return RECEIVE;
"insert"	return INSERT;
"delete"	return DELETE;
"update"	return UPDATE;
"parent"	return PARENT;
"set"		return SET;
"or"		return OR;
"lo_t"		return LO_T;
"lo_eq_t"	return LO_EQ_T;
"gr_t"		return GR_T;
"gr_eq_t"	return GR_EQ_T;
"no_eq"	return NO_EQ;
\(			return OP_BRACE;
\)			return CL_BRACE;
\{			return OP_C_BRACE;
\}			return CL_C_BRACE;
\[			return OP_SQ_BRACE;
\]			return CL_SQ_BRACE;
:			return COLON;
\$			return DOLLAR;
\"			return QUOTE;
,			return COMMA;
True		return TRUE;
False		return FALSE;
[a-zA-Z][a-zA-Z_0-9]*		{yylval.string = strdup(yytext); return STRING;}
[-]?([0-9]+)?\.[0-9]+		{yylval.vfloat = strtod(yytext, NULL); return FLOAT;}
[-]?[0-9]+					{yylval.vint = atoi(yytext); return INT;}
[ \t\n]				;
.					{ECHO; yyerror ("unexpected character");}

%%

int yywrap(void){
    return 1;
}