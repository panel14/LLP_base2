%{
void yyerror(char* str);
int yylex();

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include "query.h"

struct query query = {0};
struct extendedComparator* comp;

size_t valueType;
size_t bytesCount = 0;
size_t filtersCount = 0;

char[4][7] commandsStr = {
    "RECEIVE", "DELETE", "INSERT", "UPDATE"
};

void printQuery();
void setCurOperation(uint8_t opCode);
void setCurValue(char* key, uint64_t value, double valReal);
void appendValSetting(char* key, uint64_t value, double valReal);
void setComparator();
void switchFilter();
void setCommand(uint8_t command);
void* dmalloc(size_t sizeOf);
void printMemory();
%}

%union {uint64_t num; char* string; float floatNum};
%token STORAGE
%token RECEIVE INSERT DELETE UPDATE
%token <string> PARENT STRING
%token SET OR
%token LO_T LO_EQ_T GR_T GR_EQ_T NO_EQ
%token OP_BRACE CL_BRACE
%token OP_C_BRACE CL_C_BRACE
%token OP_SQ_BRACE CL_SQ_BRACE
%token COLON DOLLAR QUOTE COMMA
%token <num> FALSE TRUE INT
%token <fnum> FLOAT
%type <num> bool value operation comp

%%

syntax: mongosh {printQuery();};

mongosh: STORAGE RECEIVE OP_BRACE OP_C_BRACE filters CL_C_BRACE CL_BRACE {setCommand(0);}
         |
         STORAGE DELETE OP_BRACE OP_C_BRACE filters CL_C_BRACE CL_BRACE {setCommand(1);}
         |
         STORAGE INSERT OP_BRACE parent COMMA values CL_BRACE {setCommand(2);}
         |
         STORAGE UPDATE OP_BRACE OP_C_BRACE filters CL_C_BRACE COMMA DOLLAR SET COLON values CL_BRACE {setCommand(3);};

parent: OP_C_BRACE PARENT COLON INT CL_C_BRACE {
    setCurOperation(0);
    valueType = INT_TYPE;
    setCurValue("parent", $4, 0);
    switchFilter();
};

values: OP_C_BRACE setvs CL_C_BRACE;

filters: filter {switchFilter();} | filter COMMA filters {switchFilter();};

filter: STRING COLON value {
    float val;
    if (valueType == FLOAT_TYPE) {
        memcpy(&val, &$3, sizeof(uint64_t));
        setCurValue($1, 0, val);
    }
    else {
        setCurValue($1, $3, 0);
    }
}
        |
        STRING COLON operation {setCurValue($1, $3, 0);}
        |
        DOLLAR OR OP_SQ_BRACE filter COMMA filter CL_SQ_BRACE {setComparator();};

operation: OP_C_BRACE DOLLAR comp COLON value CL_C_BRACE {setCurOperation($3); $$ = $5;};

setvs: setv | setv COMMA setvs;

setv: STRING COLON value {
    if (valueType == FLOAT_TYPE) {
        float val;
        memcpy(&val, &$3, sizeof(uint64_t));
        appendValSetting($1, 0, val);
    }
    else {
        appendValSetting($1, $3, 0);
    }
};

value: QUOTE STRING QUOTE {valueType = STRING_TYPE; $$ = $2;}
        |
        INT {valueType = INT_TYPE; $$ = $1;}
        |
        FLOAT {valueType = FLOAT_TYPE; memcpy(&$$, &$1, sizeof(uint64_t));}
        |
        bool {valueType = INT_TYPE; $$ = $1;};

bool: TRUE {$$ = 1;}
        |
        FALSE {$$ = 0;};

comp: LO_T {$$ = 1;}
        |
        LO_EQ_T {$$ = 2;}
        |
        GR_T {$$ = 3;}
        |
        GR_EQ_T {$$ = 4;}
        |
        NO_EQ {$$ = 5;};
%%

int main(void) {
    return yyparse();
}

void* dmalloc(size_t sizeOf) {
    size += sizeOf;
    return malloc(sizeOf);
}

void printMemory() {
    printf("Memory usage: %zu [bytes]\nFilters count: %zu [filters]", bytesCount, filtersCount);
}

void appendValSetting(char* key, uint64_t value, double valReal) {
    struct valueSetting* vs = dmalloc(VS_SIZE);
    struct keyValuePair kv = {.key = key, .valueType = valueType};
    kv.valueReal = valReal;
    kv.valueInt = value;

    vs->kv = kv;
    vs->next = query.settingsList;
    query.settingsList = vs;
}

void setCurOperation(uint8_t opCode) {
    struct extendedComparator* temp = dmalloc(EXTEND_COMP_SIZE);
    temp->next = comp;
    temp->opCode = opCode;
    comp = temp;
}

void setCurValue(char* key, uint64_t value, double valReal) {
    struct keyValuePair kv = {.key = key, .valueType = valueType};
    kv.valueReal = valReal;
    kv.valueInt = value;
    comp->kv = kv;
}

void setComparator() {
    struct extendedComparator* temp = NULL;
    temp = comp->next-next;
    comp->connected = comp->next;
    comp->next = temp;
}

void setCommand(uint8_t command) {
    query.command = command;
}

void switchFilter() {
    struct filter* filter = dmalloc(FILTER_SIZE);
    struct comparator* temp = dmalloc(COMP_SIZE);
    filter->next = query.filtersList;

    if (comp->connected) {
        temp->next = dmalloc(COMP_SIZE);
        temp->next->opCode = comp->connected->opCode;
        temp->next->kv = comp->connected->kv;
    }
    temp->opCode = comp->opCode;
    temp->kv = comp->kv;

    if (query.filtersList) {
        query.filtersList->compList = temp;
    }
    else {
        filter->compList = temp;
        query.filtersList = filter;
        filter = dmalloc(FILTER_SIZE);
        filter->next = query.filtersList;
    }

    comp = comp->next;
    query.filtersList = filter;
}

void printQuery() {
    printf("Command: %x [%s]\n", query.command, commandsStr[query.command]);
    filtersCount = 0;
    size_t compCount = 0;

    printf("-> Filters: \n");

    while(query.filtersList) {
        if (query.filtersList->compList) printf("--> Filter %zu:\n", filtersCount++);

        while(query.filtersList->compList) {
            char* key = query.filtersList->compList->kv.key;
            uint64_t value = query.filtersList->compList->kv.valueInt;
            float fValue = query.filtersList->compList->kv.valueReal;

            printf("---> Comparator %zu:\n", compCount++);
            printf("----> Key '%s'\n----> Operation '%d'\n", key, query.filtersList->compList->opCode);

            switch(query.filtersList->compList->kv.valueType) {
                case STRING_TYPE: printf("----> Value '%s'\n", value); break;
                case INT_TYPE: printf("----> Value '%d'\n", value); break;
                case FLOAT_TYPE: printf("----> Value '%f'\n", value); break;
            }
            query.filtersList->compList = query.filtersList->compList->next;
        }
        printf("\n");
        compCount = 0;
        query.filtersList = query.filtersList->next;
    }

    if (query.settingsList) {
        printf("-> Settings: \n");
    }

    while(query.settingsList) {
        printf("--> Key '%s'\n", query.settingsList->kv.key);
        switch(query.settingsList->kv.valueType) {
            case STRING_TYPE: printf("---> Value '%s'\n", query.settingsList->kv.valueInt); break;
            case INT_TYPE: printf("---> Value '%lu'\n", query.settingsList->kv.valueInt); break;
            case FLOAT_TYPE: printf("---> Value '%f'\n", query.settingsList->kv.valueReal); break;
        }
        printf("\n");
        query.settingsList = query.settingsList->next;
    }

    printMemory();

}

void yyerror(char* str) {
    fprintf(stderr, "%s\n", str);
}
