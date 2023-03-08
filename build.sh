yacc --verbose --debug -d mongo.y
lex root.lex
gcc -w lex.yy.c y.tab.c -o out
./out < command.mso
rm lex.yy.c y.tab.c y.tab.h out