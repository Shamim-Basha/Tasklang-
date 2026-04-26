%{
#include "parser.tab.h"
#include <stdlib.h>
#include <string.h>
%}

%option yylineno

NUM [0-9]

%%
[ \t\r\n]+                     	 	; /* Ignore whitespace */
"TASK"                         	 	{return TASK;}
"RUN"                          	 	{return RUN;}
"EVERY"                         	{return EVERY;}
"DAY"                          	 	{return DAY;}	
"WEEK"                          	{return WEEK;}
"ON"                            	{return ON;}
"AT"                            	{return AT;}
"AFTER"                         	{return AFTER;}
"BEFORE"                        	{return BEFORE;}
"DEPENDS"                       	{return DEPENDS;}
"IF"                            	{return IF;}
"success"|"SUCCESS"             	{return SUCCESS;}
"failure"|"FAILURE"             	{return FAILURE;}
"MONDAY"                        	{return MONDAY;}
"TUESDAY"                       	{return TUESDAY;}
"WEDNESDAY"                     	{return WEDNESDAY;}
"THURSDAY"                      	{return THURSDAY;}
"FRIDAY"                        	{return FRIDAY;}
"SATURDAY"                      	{return SATURDAY;}
"SUNDAY"                        	{return SUNDAY;}
\"[A-Za-z][A-Za-z0-9]*\.[A-Za-z]+\" 	{ yylval.str = strdup(yytext); return FILENAME; }
{NUM}{NUM}:{NUM}{NUM}            	{ yylval.str = strdup(yytext); return TIME;}
[A-Za-z][A-Za-z0-9]*             	{ yylval.str = strdup(yytext); return IDENTIFIER; }
\"                             		{return '"';}
\.                             		{return '.';}
"{"                            		{return LCURL;}
"}"                            		{return RCURL;}
.                              		{return yytext[0];}

%%