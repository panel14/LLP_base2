%{
void yyerror (char *s);
int yylex();
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include "query.h"

struct query query = {0};
struct fullComparator* cmp;

size_t vtype;
size_t bytesCount = 0;
size_t filtersCount = 0;

char commandsStr[4][8] = {
        "RECEIVE", "DELETE", "INSERT", "UPDATE"
};

char operationStr[6][20] = {
        "none", "LOWER THAN", "LOWER EQUALS THAN", "GREATER THAN", "GREATER EQUALS THAN", "NOT EQUALS"
};

void printQuery();
void setCurOper(uint8_t operation);
void setCurVal(char* key, uint64_t valInt, double valReal);
void addValSetting(char* key, uint64_t valInt, double valReal);
void switchFilter();
void setComp();
void setCommand(uint8_t command);
void *dmalloc(size_t sizeOf);
void printMemory();
%}

%union {uint64_t vint; char *string; float vfloat;}
%token STORAGE
%token RECEIVE INSERT DELETE UPDATE
%token <string> PARENT STRING
%token SET OR
%token LO_T LO_EQ_T GR_T GR_EQ_T NO_EQ
%token OP_BRACE CL_BRACE
%token OP_C_BRACE CL_C_BRACE
%token OP_SQ_BRACE CL_SQ_BRACE
%token COLON DOLLAR COMMA QUOTE
%token <vint> FALSE TRUE INT
%token <vfloat> FLOAT
%type <vint> bool value operation comp

%%

syntax: mongosh {printQuery();};

mongosh: STORAGE RECEIVE OP_BRACE OP_C_BRACE filters CL_C_BRACE CL_BRACE {setCommand(0);}
|
STORAGE DELETE OP_BRACE OP_C_BRACE filters CL_C_BRACE CL_BRACE {setCommand(1);}
|
STORAGE INSERT OP_BRACE parent_def COMMA vals_def CL_C_BRACE {setCommand(2);}
|
STORAGE UPDATE OP_BRACE OP_C_BRACE filters CL_C_BRACE COMMA DOLLAR SET COLON vals_def CL_BRACE {setCommand(3);};

parent_def : OP_C_BRACE PARENT COLON INT CL_C_BRACE {setCurOper(0);
    vtype = INT_TYPE;
    setCurVal("parent", $4, 0);
    switchFilter();};

vals_def : OP_C_BRACE set_vals CL_C_BRACE;

filters : filter {switchFilter();} | filter COMMA filters {switchFilter();};

filter : STRING COLON value {
    setCurOper(0);
    float val;
    if (vtype == FLOAT_TYPE){
        memcpy(&val, &$3, sizeof(uint64_t));
        setCurVal($1, 0, val);
    }else {
        setCurVal($1, $3, 0);
    }
}
|
STRING COLON operation {setCurVal($1, $3, 0);}
|
DOLLAR OR OP_SQ_BRACE filter COMMA filter CL_SQ_BRACE {setComp();}
;

operation: OP_C_BRACE DOLLAR comp COLON value CL_C_BRACE {setCurOper($3); $$ = $5;};

set_vals : set_val | set_val COMMA set_vals

set_val : STRING COLON value {
    if (vtype == FLOAT_TYPE){
        float val;
        memcpy(&val, &$3, sizeof(uint64_t));
        addValSetting($1, 0, val);
    }else {
        addValSetting($1, $3, 0);
    }
};

value : QUOTE STRING QUOTE {vtype = STRING_TYPE; $$ = $2;}
|
INT {vtype = INT_TYPE; $$ = $1;}
|
FLOAT {vtype = FLOAT_TYPE; memcpy(&$$, &$1, sizeof(uint64_t));}
|
bool {vtype = INT_TYPE; $$ = $1;};

bool : TRUE {$$ = 1;} | FALSE {$$ = 0;};

comp : LO_T {$$ = 1;}
|
LO_EQ_T {$$ = 2;}
|
GR_T {$$ = 3;}
|
GR_EQ_T {$$ = 4;}
|
NO_EQ {$$ = 5;};
%%

int main (void) {
    return yyparse ();
}



void *dmalloc(size_t sizeOf){
    bytesCount += sizeOf;
    return malloc(sizeOf);
}

void printMemory(){
    printf("Memory usage: %zu bytes; %zu filters;\n", bytesCount, filtersCount);
}

void addValSetting(char* key, uint64_t valInt, double valReal){
    struct valueSetting* vs = dmalloc(VS_SIZE);
    struct keyValuePair kv = {.key = key, .valueType = vtype};
    kv.valueReal = valReal;
    kv.valueInt = valInt;
    vs->kv = kv;
    vs->next = query.settingsList;
    query.settingsList = vs;

}

void setCurOper(uint8_t operation){
    struct fullComparator* tmp = dmalloc(FULL_COMP_SIZE);
    tmp->next = cmp;
    tmp->operation = operation;
    cmp = tmp;

}

void setCurVal(char* key, uint64_t valInt, double valReal){
    struct keyValuePair kv = {.key = key, .valueType = vtype};
    kv.valueReal = valReal;
    kv.valueInt = valInt;
    cmp->kv = kv;
}

void switchFilter(){
    struct filter* f = dmalloc(FILTER_SIZE);
    struct comparator* tmp = dmalloc(COMP_SIZE);
    f->next = query.filtersList;

    if (cmp->connected){
        tmp->next = dmalloc(COMP_SIZE);
        tmp->next->operation = cmp->connected->operation;
        tmp->next->kv = cmp->connected->kv;
    }
    tmp->operation = cmp->operation;
    tmp->kv = cmp->kv;

    if (query.filtersList)
        query.filtersList->compList = tmp;
    else{
        f->compList = tmp;
        query.filtersList = f;
        f = dmalloc(FILTER_SIZE);
        f->next = query.filtersList;
    }

    cmp = cmp->next;
    query.filtersList = f;
}

void setComp(){
    struct fullComparator* tmp = NULL;
    tmp = cmp->next->next;
    cmp->connected = cmp->next;
    cmp->next = tmp;
}

void setCommand(uint8_t command){
    query.command = command;
}

void printQuery(){
    uint8_t qCom = query.command;
    printf("Command: %s (%x)\n", commandsStr[qCom], qCom);
    filtersCount = 0;
    size_t compCount = 0;
    printf("-> Filters:\n");
    while (query.filtersList){
        if (query.filtersList->compList)
            printf("--> Filter %zu:\n", filtersCount++);
        while (query.filtersList->compList){
            char* key = query.filtersList->compList->kv.key;
            uint64_t value = query.filtersList->compList->kv.valueInt;
            float fvalue = query.filtersList->compList->kv.valueReal;

            printf("---> Comparator %zu:\n", compCount++);
            uint8_t opCode = query.filtersList->compList->operation;
            printf("---> Key '%s'\n---> Operation %s (%d)\n", key, operationStr[opCode], opCode);

            switch(query.filtersList->compList->kv.valueType){
                case STRING_TYPE: printf("---> Value '%s'\n", value); break;
                case INT_TYPE: printf("---> Value '%d'\n", value); break;
                case FLOAT_TYPE: printf("---> Value '%f'\n", fvalue); break;
            }
            query.filtersList->compList = query.filtersList->compList->next;
        }
        printf("\n");
        compCount = 0;
        query.filtersList = query.filtersList->next;
    }
    if (query.settingsList)
        printf("-> Settings: \n");
    while (query.settingsList){
        printf("--> Key '%s'\n", query.settingsList->kv.key);
        switch(query.settingsList->kv.valueType){
            case STRING_TYPE: printf("--> Value '%s'\n", query.settingsList->kv.valueInt); break;
            case INT_TYPE: printf("--> Value '%lu'\n", query.settingsList->kv.valueInt); break;
            case FLOAT_TYPE: printf("--> Value '%f'\n", query.settingsList->kv.valueReal); break;
        }
        printf("\n");
        query.settingsList = query.settingsList->next;
    }

    printMemory();
}

void yyerror (char *s) {fprintf (stderr, "%s\n", s);}