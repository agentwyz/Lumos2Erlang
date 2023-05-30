%{
(* Copyright International Digital Economy Academy, all rights reserved *)
open Parser_util
%}

%token <char> CHAR
%token <int> INT
%token <float> FLOAT
%token <string> STRING
%token <string> LIDENT
%token <string> UIDENT
%token <string > COMMENT
%token NEWLINE
%token <string> INFIX1


%token <string> INFIX2
%token <string> INFIX3
%token <string> INFIX4

%token EOF
%token FALSE
%token TRUE
%token IMPORT          "import"
%token BREAK           "break"
%token CONTINUE        "continue" 
%token STRUCT          "struct"
%token ENUM            "enum" 
%token EQUAL           "=" 

%token LPAREN          "(" 
%token RPAREN          ")"

%token COMMA          "," 
%token MINUS           "-" 
%token MINUSDOT        "-." 
%token <string>DOT_LIDENT            
%token <string>COLONCOLON_UIDENT
%token COLON           ":"
%token COLONEQUAL      ":="
%token SEMI           
%token LBRACKET        "[" 
%token <string> PLUS           "+" 
%token <string> PLUSDOT        "+." 
%token RBRACKET       "]" 

%token UNDERSCORE      "_" 
%token BAR             "|" 

%token LBRACE          "{"
%token RBRACE          "}" 

%token AMPERAMPER     "&&" 
%token BARBAR          "||" 
%token <string>PACKAGE_NAME
/* Keywords */

%token AS              "as" 
%token ELSE            "else" 
%token FN            "fn"
%token TOPLEVEL_FN   "func"
%token IF             "if" 
%token LET            "let"
%token VAR            "var" 
%token MATCH          "match" 
%token MUTABLE        "mut" 
%token TYPE            "type" 
%token FAT_ARROW     "=>" 
%token WHILE           "while" 
%token RETURN          "return"

%nonassoc "as"
%right "|"
%nonassoc "="
%right BARBAR
%right AMPERAMPER


%left INFIX1  
%left INFIX2 PLUS PLUSDOT MINUS MINUSDOT
%left INFIX3 
%right INFIX4
%nonassoc prec_unary_minus
%start    structure


%type <Syntax.impls> structure
%type <Compact.semi_expr_prop > statement_expr
%%

non_empty_list_commas_rev(X):
  | x = X  {}
  | xs=non_empty_list_commas_rev(X) "," x=X {}

non_empty_list_commas( X):
  | xs = non_empty_list_commas_rev(X) ; ioption(",") {}

%inline list_commas( X):
  | {}
  | non_empty_list_commas(X) {}

non_empty_list_semi_rev_aux(X):
  | x = X  {}
  | xs=non_empty_list_semi_rev_aux(X) ; SEMI ;  x=X {}

%inline non_empty_list_semis_rev(X):
  | xs = non_empty_list_semi_rev_aux(X) ; ioption(SEMI) {}

non_empty_list_semis(X):
  | non_empty_list_semis_rev(X) {}

%inline list_semis_rev(X):
  | {}
  | non_empty_list_semis_rev(X) {}

%inline list_semis(X): 
  | {}
  | non_empty_list_semis(X){}


%inline id(x): x {}
%inline opt_annot: option(":" t=type_ {}) {}
%inline parameters : delimited("(",separated_list(",",id(b=binder t=opt_annot {})), ")") {}
optional_type_parameters:
  | params = option(delimited("[",separated_nonempty_list(",",UIDENT), "]")) {}
optional_type_arguments:
  | params = option(delimited("[" ,separated_nonempty_list(",",type_), "]")) {}     
fun_header:
  "func"
    f=binder
    /* TODO: move the quants before self */
    quants=optional_type_parameters
    ps=option(parameters)
    ts=opt_annot
    {}


%inline block_expr: "{" ls=list_semis_rev(statement_expr) "}" {}
%inline error_block: error {}
val_header : mut=id("let" {}| "var"{}) binder=binder t=opt_annot {}
structure : list_semis(structure_item) EOF {}
structure_item:
  | type_header=type_header components=type_def {}
  | val_header=val_header  "=" expr = expr {}
  | t=fun_header "=" mname=STRING fname=STRING {}
  | t=fun_header body=block_expr {}
type_header: "type" tycon=LIDENT params=optional_type_parameters {}    


qual_ident:
  | i=LIDENT {}
  | ps=PACKAGE_NAME id = DOT_LIDENT {}



%inline semi_expr_semi_opt: ls=non_empty_list_semis_rev(statement_expr)  {}

statement_expr:
  
  | "let" pat=pattern ty_opt=opt_annot "=" expr=expr
    {}
  | binder=binder ":=" expr=expr 
    {}
  | "var" binder=binder ty=opt_annot "=" expr=expr 
    {}           
  | "fn" binder=binder params=parameters ty_opt=opt_annot block = block_expr
    {}
  | "break" {}
  | "continue" {}  
  | while_expr {}
  | "return" expr = option(expr) {}
  | a=expr  {}  

while_expr:
  | "while" cond=infix_expr b=block_expr
    {}
  | "while" cond=infix_expr b=error_block  
    {}


if_expr:
   | "if"  b=infix_expr ifso=block_expr "else" ifnot=block_expr
   | "if"  b=infix_expr ifso=block_expr "else" ifnot=if_expr  {}
   | "if"  b=infix_expr ifso=block_expr {}
   | "if" b=infix_expr ifso=error_block {}


match_expr:
  | "match" e=infix_expr "{"  mat=non_empty_list_semis( pattern "=>" expr {})  "}"  {}
  | "match" e=infix_expr "{""}" {}
  | "match" e=infix_expr error {}
  
expr:
  | infix_expr 
  | match_expr      
  | if_expr {}


infix_expr:
  | op=id(PLUS {} |PLUSDOT{}) e=expr %prec prec_unary_minus {}
  | op=id(MINUS{}|MINUSDOT{}) e=expr %prec prec_unary_minus {}
  | simple_expr  {}
  | lhs=expr op=infixop rhs=expr {}
  | lv = left_value "=" e=expr {}  

%inline left_value:
 | var=var {}
 | record=simple_expr  name=DOT_LIDENT {}
 | obj=simple_expr  "[" ind=expr "]" {}

simple_expr:
  | "{" fs=record_defn "}" {}
  // | "{" fs=list_commas( l=label ":" e=expr {}) "}" {}
  // | "fn"  parameters "=>" atomic_expr  
  | "{" x=semi_expr_semi_opt "}" {}  
  | "fn" ps=parameters f = block_expr  {}
  | e = atomic_expr {}
  | "_" {}
  | v=var {}
  | c=constr {}
  // | constr_longident_expr {} 
  | obj=simple_expr  "[" index=expr "]" {}
  | f=simple_expr "(" args=list_commas(expr) ")" {}
  | record=simple_expr  name=DOT_LIDENT {}
  | "("  bs=list_commas(expr) ")" {}  
  | "(" expr ":" type_ ")" 
    {}
  | "[" es = list_commas(expr) "]" {}  

%inline label:
  name = LIDENT {}
%inline binder:
  name = LIDENT {}
%inline var:
  name = qual_ident {}

%inline atomic_expr:
  | TRUE {}
  | FALSE {}
  | CHAR {}
  | INT {}
  | FLOAT {}
  | STRING {}


 %inline infixop:
  | INFIX4
  | INFIX3  
  | INFIX2
  | INFIX1 {}
  | PLUS {}
  | PLUSDOT  {}
  | MINUS  {}
  | MINUSDOT {}
  | AMPERAMPER {}
  | BARBAR {}

%inline constr:
  | name = UIDENT {}
  /* TODO: two tokens or one token here? */
  | type_name=LIDENT constr_name=COLONCOLON_UIDENT
    {}

pattern:
  | simple_pattern {}
  | b=binder "as" p=pattern {}
  | pat1=pattern "|" pat2=pattern {}
  

simple_pattern:
  | TRUE {}
  | FALSE {}
  | CHAR {}
  | INT {}
  | FLOAT {}
  | STRING {}
  | UNDERSCORE {}
  | b=binder  {}
  | constr=constr ps=option("(" t=separated_nonempty_list(",",pattern) ")" {}){}
  | "(" pattern ")" {}
  | "(" p = pattern "," ps=separated_nonempty_list(",",pattern) ")"  {}     
  | "(" pat=pattern ":" ty=type_ ")" {}
  // | "#" "[" pat = pat_list "]" {}
  | "[" lst=separated_list(",",pattern) "]" {}
  //| "{" p=separated_list(",", l=label ":" p=pattern {}) "}" {}
  | "{" p=fields_pat "}" {}
  
type_:
  | "(" t=type_ "," ts=separated_nonempty_list(",", type_)")" {}
  | "(" t=type_ "," ts=separated_nonempty_list(",",type_) ")" "=>" rty=type_ {}
  | "(" ")" "=>" rty=type_ {}
  | "(" t=type_ ")" rty=option("=>" t2=type_{})
      {} 
  | UIDENT {}  
  // | "(" type_ ")" {}
  | id=qual_ident params=optional_type_arguments {}
  | "_" {}
/* type declaration */


type_def:
  | /* empty */ {}
  | "struct" "{" fs=list_semis(record_decl_field) "}"  {}
  | "enum" "{" fs=list_semis(id=UIDENT opt=option("("  ts=separated_nonempty_list(",",type_)")"{}) {}) "}" {}

record_decl_field:
  | mutflag = option("mut") name=LIDENT ":" ty=type_ {}

record_defn:
  | {}
  /* ending comma is required for single field {} for resolving the ambiguity between record punning {} and block {} */
  | l=label_pun "," fs=list_commas(record_defn_single ) {}
  | l=labeled_expr option(",") {}
  /* rule out {} */
  | l=labeled_expr "," fs=non_empty_list_commas(record_defn_single) {}

record_defn_single:
  | labeled_expr 
  | label_pun {}

%inline labeled_expr:
  | l=label ":" e=expr {}
%inline label_pun:  
  | l=label {}
    
fields_pat:
  | p=separated_list(",", f=fields_pat_single {}) {}

fields_pat_single:
  | fpat_labeled_pattern
  | fpat_label_pun {}

%inline fpat_labeled_pattern:
  | l=label ":" p=pattern {}

%inline fpat_label_pun:
  | l=label {}