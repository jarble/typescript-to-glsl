{
  const typeMap = {
    number:"float",
    boolean:"bool",
    vec2:"vec2",
    vec3:"vec3",
    vec4:"vec4"
  };

  const jsFuncMap = {
    "Math.abs":"abs","Math.acos":"acos","Math.asin":"asin","Math.atan":"atan",
    "Math.atan2":"atan","Math.ceil":"ceil","Math.cos":"cos","Math.exp":"exp",
    "Math.floor":"floor","Math.log":"log","Math.max":"max","Math.min":"min",
    "Math.pow":"pow","Math.sin":"sin","Math.sqrt":"sqrt","Math.tan":"tan"
  };

  const jsConstMap = {
    "Math.PI":"3.141592653589793",
    "Math.E":"2.718281828459045"
  };

  function mapType(t){ return typeMap[t]||t||"float"; }

  function mapFunc(expr){
    for(const key in jsFuncMap){
      if(expr.startsWith(key+"(")){
        const args = expr.slice(key.length+1, expr.length-1);
        return jsFuncMap[key]+"("+args+")";
      }
    }
    if(jsConstMap[expr]) return jsConstMap[expr];
    return expr;
  }

  function flatten2DArray(elements){
    const rows = elements.map(e => e.slice(8,-1).split(","));
    const rowCount = rows.length;
    const colCount = rows[0].length;
    if(rowCount === colCount){
      return "mat"+rowCount+"("+rows.flat().join(",")+")";
    }
    return "float[]("+elements.join(",")+")";
  }

  function emitComment(c){ return c + "\n"; }
}

/* --- Start --- */
Start
  = _ items:(TopLevelItem (_ TopLevelItem)*)? _ { 
      let all = items ? [items[0]].concat(items[1].map(t=>t[1])) : [];
      return all.join("");
    }

/* --- Top-level items --- */
TopLevelItem
  = CommentStmt
  / FunctionDecl
  / JSFunction
  / ConstDecl
  / VarDecl
  / AssignmentStmt
  / ForStmt
  / WhileStmt

/* --- Comments --- */
CommentStmt
  = c:Comment { return emitComment(c); }

Comment
  = SingleLineComment / MultiLineComment

SingleLineComment
  = "//" text:[^\r\n]* { return "//"+text.join(""); }

MultiLineComment
  = "/*" text:(!"*/" .)* "*/" { return "/*"+text.join("")+"*/"; }

/* --- Constants --- */
ConstDecl
  = "const" __ id:Identifier _ "=" _ expr:(ArrayLiteral / Expression) _ ";" {
      if(typeof expr === "string" && expr.startsWith("float[](")){
        return "#define "+id+" "+expr;
      } else {
        return "#define "+id+" "+mapFunc(expr);
      }
    }

/* --- TypeScript-style function --- */
FunctionDecl
  = "function" __ id:Identifier _ "(" _ params:ParamList? _ ")" _ ":" _ ret:Type _ _ body:Block {
      const ps = params ? params.join(", ") : "";
      return mapType(ret)+" "+id+"("+ps+") "+body;
    }

/* --- JavaScript macro function --- */
JSFunction
  = "function" __ id:Identifier _ "(" _ params:IdentifierList? _ ")" _ "{" _ body:MacroBody _ "}" {
      const ps = params ? params.join(",") : "";
      return "#define "+id+"("+ps+") "+body;
    }

MacroBody
  = "return" __ expr:Expression _ ";" { return expr; }

/* --- Parameters --- */
ParamList
  = head:Param tail:(_ "," _ Param)* { return [head].concat(tail.map(t=>t[3])); }
Param
  = id:Identifier _ ":" _ t:Type { return mapType(t)+" "+id; }
IdentifierList
  = head:Identifier tail:(_ "," _ Identifier)* { return [head].concat(tail.map(t=>t[3])); }

/* --- Statements --- */
Statement
  = CommentStmt
  / AssignmentStmt
  / VarDecl
  / ReturnStmt
  / IfStmt
  / ExprStmt
  / Block
  / ForStmt
  / WhileStmt

VarDecl
  = ("var" / "let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" { return mapType(t)+" "+id+" = "+expr+";"; }
  / ("var" / "let") __ id:Identifier _ "=" _ expr:Expression _ ";" { return "float "+id+" = "+expr+";"; }

AssignmentStmt
  = id:Identifier _ op:AssignOp _ expr:Expression _ ";" { return id+" "+op+" "+expr+";"; }

AssignOp
  = "+=" / "-=" / "*=" / "/=" / "="

ReturnStmt
  = "return" __ expr:Expression _ ";" { return "return "+expr+";"; }

/* --- If / else if / else --- */
IfStmt
  = "if" _ "(" _ cond:Expression _ ")" _ then:Block _ elsePart:ElseClause? {
      return "if("+cond+") "+then+(elsePart?" "+elsePart:"");
    }

ElseClause
  = "else" _ stmt:(IfStmt / Block) { return "else "+stmt; }

/* --- For and While --- */
ForStmt
  = "for" _ "(" _ init:ForInit? _ ";" _ cond:Expression? _ ";" _ update:Expression? _ ")" _ body:Block {
      return "for("+(init||"")+";"+(cond||"")+";"+(update||"")+") "+body;
    }

ForInit
  = VarDecl
  / AssignmentStmt
  / Expression

WhileStmt
  = "while" _ "(" _ cond:Expression _ ")" _ body:Block {
      return "while("+cond+") "+body;
    }

/* --- Expression statements --- */
ExprStmt
  = expr:Expression _ ";" { return expr+";"; }

/* --- Block --- */
Block
  = "{" _ stmts:(Statement (_ Statement)*)? _ "}" {
      let allStmts = stmts ? [stmts[0]].concat(stmts[1].map(t=>t[1])) : [];
      return "{\n"+allStmts.join("")+"\n}";
    }

/* --- Expressions --- */
Expression = Comparison

Comparison
  = left:AddSub tail:(_ CompOp _ AddSub)* { return tail.reduce((acc,t)=>acc+" "+t[1]+" "+t[3], left); }
CompOp = "==" / "!=" / "<=" / ">=" / "<" / ">"

AddSub
  = left:MulDiv tail:(_ ("+" / "-") _ MulDiv)* { return tail.reduce((acc,t)=>acc+" "+t[1]+" "+t[3], left); }

MulDiv
  = left:Unary tail:(_ ("*" / "/") _ Unary)* { return tail.reduce((acc,t)=>acc+" "+t[1]+" "+t[3], left); }

Unary
  = "-" _ v:Unary { return "-"+v; }
  / Primary

Primary
  = "(" _ e:Expression _ ")" { return "("+e+")"; }
  / ArrayLiteral
  / MathCall
  / FuncCall
  / IdentifierDot
  / Identifier
  / Number

/* --- Arrays --- */
ArrayLiteral
  = "[" _ elements:ExprList _ "]" {
      if(elements.length>0 && elements.every(e=>typeof e==="string" && e.startsWith("float[]("))){
        return flatten2DArray(elements);
      } else {
        return "float[]("+elements.join(",")+")";
      }
    }

ExprList
  = head:Expression tail:(_ "," _ Expression)* { return [head].concat(tail.map(t=>t[3])); }

/* --- Function calls --- */
MathCall
  = "Math." fname:Identifier "(" _ args:ArgList? _ ")" { return mapFunc("Math."+fname+"("+((args||[]).join(","))+")"); }

FuncCall
  = id:Identifier "(" _ args:ArgList? _ ")" { return id+"("+(args?args.join(","):"")+")"; }

ArgList
  = head:Expression tail:(_ "," _ Expression)* { return [head].concat(tail.map(t=>t[3])); }

IdentifierDot
  = left:Identifier "." right:Identifier { return left+"."+right; }

/* --- Tokens --- */
Identifier = $([a-zA-Z_$][a-zA-Z0-9_$]*)
Number = $([0-9]+ ("." [0-9]+)?) { return text(); }

Type
  = "number" { return "number"; }
  / "boolean" { return "boolean"; }
  / "vec2" { return "vec2"; }
  / "vec3" { return "vec3"; }
  / "vec4" { return "vec4"; }

/* --- Whitespace --- */
_ = [ \t\r\n]*
__ = [ \t\r\n]+
