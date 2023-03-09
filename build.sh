yacc --verbose --debug -d main.y
lex rules.lex
gcc -w lex.yy.c y.tab.c -o out
./out < query.mso
rm lex.yy.c y.tab.c y.tab.h out