{
  const typeMap = {
    number: "float",
    boolean: "bool",
    vec2: "vec2",
    vec3: "vec3",
    vec4: "vec4",
    string: "float[]"
  };

  const jsFuncMap = {
    "Math.abs":"abs",
    "Math.acos":"acos",
    "Math.asin":"asin",
    "Math.atan":"atan",
    "Math.atan2":"atan",
    "Math.ceil":"ceil",
    "Math.cos":"cos",
    "Math.exp":"exp",
    "Math.floor":"floor",
    "Math.log":"log",
    "Math.max":"max",
    "Math.min":"min",
    "Math.pow":"pow",
    "Math.sin":"sin",
    "Math.sqrt":"sqrt",
    "Math.tan":"tan",
    "Math.sign":"sign",
    "Math.trunc":"trunc",
    "Math.round":"round",
    "Math.hypot":"hypot",
    "Math.cbrt":"cbrt",
    "Math.expm1":"expm1",
    "Math.log1p":"log1p",
    "Math.sinh":"sinh",
    "Math.cosh":"cosh",
    "Math.tanh":"tanh",
    "Math.asinh":"asinh",
    "Math.acosh":"acosh",
    "Math.atanh":"atanh",
    "Math.exp2": (x) => `pow(2.0, ${x})`,
    "Math.log2": "log2",
    "Math.log10": "log10"
  };

  const jsConstMap = {
    "Math.E": "(exp(1.0))",
    "Math.LN2": "(log(2.0))",
    "Math.LN10": "(log(10.0))",
    "Math.LOG2E": "(1.0/log(2.0))",
    "Math.LOG10E": "(1.0/log(10.0))",
    "Math.PI": "(4.0*atan(1.0))",
    "Math.SQRT1_2": "(sqrt(0.5))",
    "Math.SQRT2": "(sqrt(2.0))"
  };

  const glslBuiltIns = [
    "abs","acos","asin","atan","ceil","cos","exp","floor","log","max","min","pow",
    "sin","sqrt","tan","mod","clamp","mix","step","smoothstep","length","normalize",
    "dot","cross","sign","trunc","round","sinh","cosh","tanh","asinh","acosh","atanh",
    "true","false"
  ];

  function mapType(tsType){
    if(!tsType) return "float";
    if(tsType.endsWith("[]"))
      return mapType(tsType.slice(0,-2))+"[]";
    return typeMap[tsType] || tsType;
  }

  function mapFunc(expr){
    for(const k in jsFuncMap){
      if(expr.startsWith(k+"(")){
        const args = expr.slice(k.length+1,expr.length-1);
        switch(k){
          case "Math.hypot": return "(length(vec" + args.split(",").length + "(" + args + ")))";
          case "Math.cbrt": return "(pow(" + args + ", 1.0/3.0))";
          case "Math.expm1": return "((exp(" + args + ")) - 1.0)";
          case "Math.log1p": return "(log(1.0 + (" + args + ")))";
          case "Math.exp2": return "(pow(2.0," + args + "))";
          default: return jsFuncMap[k]+"("+args+")";
        }
      }
    }
    if(jsConstMap[expr]) return jsConstMap[expr];
    return expr;
  }

  function emitComment(c){ return c+"\n"; }
  function formatNumber(n){ return n.includes(".") ? n : n+".0"; }
  function stringToFloatArray(str){
    let s = str.slice(1,-1);
    return "float[](" + Array.from(s).map(c => c.charCodeAt(0)+".0").join(",") + ")";
  }
  function compileIdent(id){
    return glslBuiltIns.includes(id) ? id : id+"_compiled";
  }
}

/* --- Start --- */
Start = _ items:(TopLevelItem (_ TopLevelItem)*)? _ {
  let all = items ? [items[0]].concat(items[1].map(t=>t[1])) : [];
  return all.join("\n");
}

/* --- Top-level items --- */
TopLevelItem
  = CommentStmt
  / ClassOrInterfaceDecl
  / TypeAliasDecl
  / EnumDecl
  / FunctionDecl
  / FunctionDeclOnly
  / JSFunction
  / ConstDecl
  / TopLevelVarDecl
  / AssignmentStmt
  / AssignmentNoSemi
  / IfStmt
  / ForStmt
  / WhileStmt
  / DoWhileStmt
  / SwitchStmt
  / ExprStmt

/* --- Type aliases --- */
TypeAliasDecl
  = "type" __ id:Identifier _ "=" _ t:Type _ ";" {
      if (t.endsWith("[]")) {
        let base = t.slice(0, -2);
        return "#define " + compileIdent(id) + " " + mapType(base) + "[]";
      } else {
        return "#define " + compileIdent(id) + " " + mapType(t);
      }
    }

/* --- Enums --- */
EnumDecl
  = "enum" __ id:Identifier _ "{" _ members:EnumMemberList? _ "}" {
      const mems = members || [];
      let lines = mems.map((m, idx) => {
        const val = m.value !== null ? m.value : idx;
        return "#define " + compileIdent(m.name) + " " + val;
      });
      return lines.join("\n");
    }

EnumMemberList
  = head:EnumMember tail:(_ "," _ EnumMember)* _ ","? { return [head].concat(tail.map(t=>t[3])); }

EnumMember
  = name:Identifier _ "=" _ value:Number { return {name, value:parseFloat(value)}; }
  / name:Identifier { return {name, value:null}; }

/* --- Statements --- */
Statement
  = CommentStmt
  / ConstStmt
  / VarDecl
  / AssignmentStmt
  / ReturnStmt
  / IfStmt
  / ExprStmt
  / Block
  / ForStmt
  / WhileStmt
  / DoWhileStmt
  / SwitchStmt

/* --- Comments --- */
CommentStmt = c:Comment { return emitComment(c); }
Comment = SingleLineComment / MultiLineComment
SingleLineComment = c:$("//" [^\r\n]*) { return c; }
MultiLineComment = c:$("/*" (!"*/" .)* "*/") { return c; }

/* --- Top-level const --- */
ConstDecl
  = "const" __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" {
      return mapType(t) + " " + compileIdent(id) + " = " + expr + ";";
    }
  / "const" __ id:Identifier _ "=" _ expr:Expression _ ";" {
      return "#define " + compileIdent(id) + " " + expr + "\n";
    }

/* --- Function-scope const --- */
ConstStmt
  = "const" __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" {
      return mapType(t) + " " + compileIdent(id) + " = " + expr + ";";
    }

/* --- Block --- */
Block
  = "{" _ stmts:(Statement (_ Statement)*)? _ "}" {
      let allStmts = stmts ? [stmts[0]].concat(stmts[1].map(t=>t[1])) : [];
      return "{\n" + allStmts.join("\n") + "\n}";
    }

/* --- Top-level variable declarations --- */
TopLevelVarDecl
  = ("var"/"let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" {
      return mapType(t)+" "+compileIdent(id)+" = "+expr+";";
    }
  / ("var"/"let") __ id:Identifier _ "=" _ expr:Expression _ ";" {
      return "#define "+compileIdent(id)+" "+expr+"\n";
    }

/* --- Function-scope variable declarations --- */
VarDecl
  = ("var"/"let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" {
      return mapType(t)+" "+compileIdent(id)+" = "+expr+";";
    }
VarDeclNoSemi
  = ("var"/"let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression {
      return mapType(t)+" "+compileIdent(id)+" = "+expr;
    }

/* --- Assignment --- */
AssignmentStmt
  = lhs:Assignable _ op:AssignOp _ rhs:Expression _ ";" { return lhs + " " + op + " " + rhs + ";"; }
AssignmentNoSemi
  = id:Assignable _ op:AssignOp _ expr:Expression { return id + " " + op + " " + expr; }

/* include bitwise assignment ops */
AssignOp = "+=" / "-=" / "*=" / "/=" / "=" / "&=" / "|=" / "^=" / "<<=" / ">>="

/* --- Return --- */
ReturnStmt = "return" __ expr:Expression _ ";" { return "return "+expr+";" }

/* --- If / else --- */
IfStmt
  = "if" _ "(" _ cond:Expression _ ")" _ then:Block _ elsePart:ElseClause? {
      return "if("+cond+") "+then+(elsePart?" "+elsePart:"");
    }
ElseClause = "else" _ stmt:(IfStmt / Block) { return "else "+stmt; }

/* --- Switch --- */
SwitchStmt
  = "switch" _ "(" _ expr:Expression _ ")" _ "{" _ cases:(CaseClause _)* _ "}" {
      return "switch("+expr+") {\n"+cases.map(c=>c[0]).join("")+"\n}";
    }
CaseClause
  = "case" __ val:Expression ":" _ stmts:((Statement _)+)? {
      let body = stmts ? stmts.map(s=>s[0]).join("") : "";
      return "case "+val+":\n"+body;
    }
  / "default" ":" _ stmts:((Statement _)+)? {
      let body = stmts ? stmts.map(s=>s[0]).join("") : "";
      return "default:\n"+body;
    }

/* --- Loops --- */
ForStmt
  = "for" _ "(" _ init:(VarDeclNoSemi / AssignmentNoSemi / Expression)? _ ";" _ cond:Expression? _ ";" _ update:(UpdateExpr / AssignmentNoSemi / Expression)? _ ")" _ body:Block {
      return "for("+(init||"")+";"+(cond||"")+";"+(update||"")+") "+body;
    }
WhileStmt
  = "while" _ "(" _ cond:Expression _ ")" _ body:Block { return "while("+cond+") "+body; }
DoWhileStmt
  = "do" _ body:Block _ "while" _ "(" _ cond:Expression _ ")" _ ";" {
      return "do "+body+" while("+cond+");";
    }

/* --- Function declarations --- */
FunctionDecl
  = "function" __ id:Identifier _ "(" _ params:ParamList? _ ")" _ ":" _ ret:Type _ _ body:Block {
      const ps = params ? params.join(", ") : "";
      return mapType(ret) + " " + compileIdent(id) + "(" + ps + ") " + body;
    }

FunctionDeclOnly
  = "function" __ id:Identifier _ "(" _ params:ParamList? _ ")" _ ":" _ ret:Type _ ";" {
      const ps = params ? params.join(", ") : "";
      return mapType(ret) + " " + compileIdent(id) + "(" + ps + ");";
    }

/* --- JS macro-style functions --- */
JSFunction
  = "function" __ id:Identifier _ "(" _ params:IdentifierList? _ ")" _ "{" _ body:MacroBody _ "}" {
      const ps = params?params.join(","):"";
      return "#define "+compileIdent(id)+"("+ps+") "+body+"\n";
    }
MacroBody = "return" __ expr:Expression _ ";" { return expr; }

/* --- Parameters --- */
ParamList = head:Param tail:(_ "," _ Param)* { return [head].concat(tail.map(t=>t[3])); }
Param = id:Identifier _ ":" _ t:Type { return mapType(t) + " " + compileIdent(id); }
IdentifierList = head:Identifier tail:(_ "," _ Identifier)* { return [head].concat(tail.map(t=>t[3])); }

/* --- Expressions --- */
Expression = LogicalOr
LogicalOr = left:LogicalAnd tail:(_ "||" _ LogicalAnd)* { return tail.reduce((acc,t)=>acc+" || "+t[3], left); }
LogicalAnd = left:Comparison tail:(_ "&&" _ Comparison)* { return tail.reduce((acc,t)=>acc+" && "+t[3], left); }
Comparison = left:BitwiseOr tail:(_ CompOp _ BitwiseOr)* { return tail.reduce((acc,t)=>acc+" "+t[1]+" "+t[3], left); }
CompOp = "==" / "!=" / "<=" / ">=" / "<" / ">"

BitwiseOr = left:BitwiseXor tail:(_ "|" _ BitwiseXor)* { return tail.reduce((acc,t)=>acc+" | "+t[3], left); }
BitwiseXor = left:BitwiseAnd tail:(_ "^" _ BitwiseAnd)* { return tail.reduce((acc,t)=>acc+" ^ "+t[3], left); }
BitwiseAnd = left:Shift tail:(_ "&" _ Shift)* { return tail.reduce((acc,t)=>acc+" & "+t[3], left); }
Shift = left:AddSub tail:(_ ("<<" / ">>") _ AddSub)* { return tail.reduce((acc,t)=>acc+" "+t[1]+" "+t[3], left); }

AddSub = left:MulDiv tail:(_ ("+" / "-") _ MulDiv)* { return tail.reduce((acc,t)=>acc+" "+t[1]+" "+t[3], left); }
MulDiv = left:Power tail:(_ ("*" / "/") _ Power)* { return tail.reduce((acc,t)=>acc+" "+t[1]+" "+t[3], left); }
Power = left:Unary tail:(_ "**" _ Unary)* { return tail.reduce((acc,t) => "pow("+acc+", "+t[3]+")", left); }

Unary = "!" _ v:Unary { return "!" + v; }
      / "~" _ v:Unary { return "~" + v; }
      / "-" _ v:Unary { return "-" + v; }
      / UpdateExpr
      / Ternary
      / Primary

UpdateExpr = id:Assignable op:("++" / "--") { return id+op; }
Ternary = cond:Primary _ "?" _ tExpr:Expression _ ":" _ fExpr:Expression { return cond+" ? "+tExpr+" : "+fExpr; }

/* --- Primary expressions --- */
Primary
  = "true" { return "true"; }
  / "false" { return "false"; }
  / "(" _ e:Expression _ ")" { return "(" + e + ")"; }
  / ArrayLiteral
  / MathCall
  / FuncCall
  / NewExpr
  / StructConstructor
  / Assignable
  / IdentifierDot
  / StringLiteral
  / Identifier
  / Number

/* --- New operator --- */
NewExpr = "new" __ id:Identifier "(" _ args:ArgList? _ ")" { return compileIdent(id) + "(" + (args ? args.join(",") : "") + ")"; }

/* --- Struct constructors --- */
StructConstructor = id:Identifier "(" _ args:ArgList? _ ")" { return compileIdent(id)+"("+(args?args.join(","):"")+")"; }

/* --- Arrays --- */
ArrayLiteral = "[" _ elements:ExprList _ "]" {
  const elems = elements.join(", ");
  switch(elements.length){
    case 2: return `vec2(${elems})`;
    case 3: return `vec3(${elems})`;
    case 4: return `vec4(${elems})`;
    default: return `float[](${elems})`;
  }
}
ExprList = head:Expression tail:(_ "," _ Expression)* { return [head].concat(tail.map(t=>t[3])); }

/* --- Math calls --- */
MathCall = "Math" _ "." _ fname:Identifier "(" _ args:ArgList? _ ")" { return mapFunc("Math."+fname+"("+((args||[]).join(","))+")"); }
FuncCall = id:Identifier "(" _ args:ArgList? _ ")" { return id+"("+(args?args.join(","):"")+")"; }
ArgList = head:Expression tail:(_ "," _ Expression)* { return [head].concat(tail.map(t=>t[3])); }

/* --- Assignable / dot-access --- */
Assignable = base:IdentifierOrCall tail:(_ AccessPart)* {
  return tail.reduce((acc,t)=>{
    const p=t[1];
    return p.type==="member"?acc+"."+p.name:acc+"["+p.index+"]";
  }, base);
}
IdentifierOrCall = NewExpr / StructConstructor / FuncCall / IdentifierDot / Identifier
AccessPart = "." name:Identifier { return {type:"member", name}; } / "[" _ idx:Expression _ "]" { return {type:"index", index:idx}; }
IdentifierDot = left:Identifier "." right:Identifier { return left+"."+right; }

/* --- String literals --- */
StringLiteral = s:$("\"" ([^\"]*) "\"") { return stringToFloatArray(s); }

/* --- Expression statements --- */
ExprStmt = expr:Expression _ ";" { return expr+";"; }

/* --- Numbers --- */
Number = n:$([0-9]+ ("." [0-9]+)?) { return formatNumber(text()); }

/* --- Classes --- */
ClassOrInterfaceDecl = kw:("class"/"interface") __ id:Identifier _ "{" _ fields:(ClassField (_ ClassField)*)? _ "}" {
  const allFields = fields?[fields[0]].concat(fields[1].map(t=>t[1])):[];
  const members = allFields.map(f=>mapType(f.type)+" "+f.name+";").join("\n");
  return "#define " + compileIdent(id) + " struct {\n"+members+"\n}";
}
ClassField = _ id:Identifier _ ":" _ t:Type _ ";" { return {name:id,type:t}; }

/* --- Types --- */
Type = base:BaseType arr:("[]")* { return base+arr.join(""); }
BaseType = "number" / "boolean" / "vec2" / "vec3" / "vec4" / "string" / Identifier

/* --- Identifier --- */
Identifier = id:$([a-zA-Z_$][a-zA-Z0-9_$]*) { return id; }

/* --- Whitespace --- */
_ = [ \t\r\n]*
__ = [ \t\r\n]+
