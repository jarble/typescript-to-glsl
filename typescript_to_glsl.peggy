{
  const typeMap = { number: "float", boolean: "bool", vec2: "vec2", vec3: "vec3", vec4: "vec4", string: "float[]" };
  const jsFuncMap = {
    "Math.abs":"abs","Math.acos":"acos","Math.asin":"asin","Math.atan":"atan",
    "Math.atan2":"atan","Math.ceil":"ceil","Math.cos":"cos","Math.exp":"exp",
    "Math.floor":"floor","Math.log":"log","Math.max":"max","Math.min":"min",
    "Math.pow":"pow","Math.sin":"sin","Math.sqrt":"sqrt","Math.tan":"tan"
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

  const glslBuiltIns = ["abs","acos","asin","atan","ceil","cos","exp","floor","log","max","min","pow","sin","sqrt","tan","mod","clamp","mix","step","smoothstep","length","normalize","dot","cross"];

  function mapType(tsType){ if(!tsType) return "float"; if(tsType.endsWith("[]")) return mapType(tsType.slice(0,-2))+"[]"; return typeMap[tsType] || tsType; }

  function mapFunc(expr){
    for(const k in jsFuncMap){
      if(expr.startsWith(k+"(")){
        const args = expr.slice(k.length+1,expr.length-1);
        return jsFuncMap[k]+"("+args+")";
      }
    }
    if(jsConstMap[expr]) return jsConstMap[expr];
    return expr;
  }

  function emitComment(c){ return c+"\n"; }
  function emitConst(id,expr){ return "#define "+id+" "+expr+"\n"; }
  function compileIdent(id){ if(glslBuiltIns.includes(id) || id.endsWith("_compiled")) return id; return id+"_compiled"; }
  function formatNumber(n){ return n.includes(".") ? n : n+".0"; }
  function stringToFloatArray(str){ let s = str.slice(1,-1); return "float[](" + Array.from(s).map(c => c.charCodeAt(0)+".0").join(",") + ")"; }
}

/* --- Start --- */
Start = _ items:(TopLevelItem (_ TopLevelItem)*)? _ { let all = items ? [items[0]].concat(items[1].map(t=>t[1])) : []; return all.join("\n"); }

/* --- Top-level items --- */
TopLevelItem = CommentStmt / ClassDecl / FunctionDecl / JSFunction / ConstDecl / TopLevelVarDecl / AssignmentStmt / AssignmentNoSemi / IfStmt / ForStmt / WhileStmt / DoWhileStmt / SwitchStmt / ExprStmt

/* --- Statements --- */
Statement = CommentStmt / VarDecl / AssignmentStmt / ReturnStmt / IfStmt / ExprStmt / Block / ForStmt / WhileStmt / DoWhileStmt / SwitchStmt

/* --- Block --- */
Block
  = "{" _ stmts:(Statement (_ Statement)*)? _ "}" { 
      let allStmts = stmts ? [stmts[0]].concat(stmts[1].map(t=>t[1])) : []; 
      return "{\n" + allStmts.join("\n") + "\n}";
  }

/* --- Comments --- */
CommentStmt = c:Comment { return emitComment(c); }
Comment = SingleLineComment / MultiLineComment
SingleLineComment = c:$("//" [^\r\n]*) { return c; }
MultiLineComment = c:$("/*" (!"*/" .)* "*/") { return c; }

/* --- Constants --- */
ConstDecl = "const" __ id:Identifier _ "=" _ expr:(ArrayLiteral / MathCall / Number / StringLiteral / Assignable) _ ";" { return emitConst(id,expr); }

/* --- Top-level variable declarations --- */
TopLevelVarDecl
  = ("var"/"let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" { return mapType(t)+" "+id+" = "+expr+";"; }
  / ("var"/"let") __ id:Identifier _ "=" _ expr:Expression _ ";" { return "#define "+id+" "+expr+"\n"; }

/* --- Function-scope variable declarations --- */
VarDecl
  = ("var"/"let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" { return mapType(t)+" "+id+" = "+expr+";"; }
VarDeclNoSemi
  = ("var"/"let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression { return mapType(t)+" "+id+" = "+expr; }

/* --- Assignment --- */
AssignmentStmt
  = lhs:DestructuringOrAssignable _ op:AssignOp _ rhs:Expression _ ";" {
      let right = typeof rhs === "string" ? rhs : rhs;
      if(lhs.type === "destructuring" && rhs.type === "array") {
        return lhs.names.map((name,i)=>name+" = "+rhs.elements[i]+";").join("\n");
      }
      return lhs.code + " " + op + " " + right + ";";
  }
AssignmentNoSemi = id:Assignable _ op:AssignOp _ expr:Expression { return id + " " + op + " " + expr; }
AssignOp = "+=" / "-=" / "*=" / "/=" / "="

/* --- Destructuring --- */
DestructuringOrAssignable = d:DestructuringPattern { return {type:"destructuring", names:d}; } / a:Assignable { return {type:"assignable", code:a}; }
DestructuringPattern = "[" _ head:Identifier tail:(_ "," _ Identifier)* _ "]" { return [head].concat(tail.map(t=>t[3])); }

/* --- Return --- */
ReturnStmt = "return" __ expr:Expression _ ";" { return "return "+expr+";" }

/* --- If / else --- */
IfStmt = "if" _ "(" _ cond:Expression _ ")" _ then:Block _ elsePart:ElseClause? { return "if("+cond+") "+then+(elsePart?" "+elsePart:""); }
ElseClause = "else" _ stmt:(IfStmt / Block) { return "else "+stmt; }

/* --- Switch --- */
SwitchStmt = "switch" _ "(" _ expr:Expression _ ")" _ "{" _ cases:(CaseClause _)* _ "}" { return "switch("+expr+") {\n"+cases.map(c=>c[0]).join("")+"\n}"; }
CaseClause = "case" __ val:Expression ":" _ stmts:((Statement _)+)? { let body = stmts ? stmts.map(s=>s[0]).join("") : ""; return "case "+val+":\n"+body; } / "default" ":" _ stmts:((Statement _)+)? { let body = stmts ? stmts.map(s=>s[0]).join("") : ""; return "default:\n"+body; }

/* --- Loops --- */
ForStmt = "for" _ "(" _ init:(VarDeclNoSemi / AssignmentNoSemi / Expression)? _ ";" _ cond:Expression? _ ";" _ update:(UpdateExpr / AssignmentNoSemi / Expression)? _ ")" _ body:Block { return "for("+(init||"")+";"+(cond||"")+";"+(update||"")+") "+body; }
WhileStmt = "while" _ "(" _ cond:Expression _ ")" _ body:Block { return "while("+cond+") "+body; }
DoWhileStmt = "do" _ body:Block _ "while" _ "(" _ cond:Expression _ ")" _ ";" { return "do "+body+" while("+cond+");"; }

/* --- Function declarations --- */
FunctionDecl
  = "function" __ id:Identifier _ "(" _ params:ParamList? _ ")" _ ":" _ ret:Type _ _ body:Block {
      const ps = params ? params.join(", ") : "";
      return mapType(ret) + " " + id + "(" + ps + ") " + body;
  }

/* --- JS macro-style functions --- */
JSFunction
  = "function" __ id:Identifier _ "(" _ params:IdentifierList? _ ")" _ "{" _ body:MacroBody _ "}" {
      const ps = params?params.join(","):""; 
      return "#define "+id+"("+ps+") "+body+"\n";
  }
MacroBody = "return" __ expr:Expression _ ";" { return expr; }

/* --- Parameters --- */
ParamList = head:Param tail:(_ "," _ Param)* { return [head].concat(tail.map(t=>t[3])); }
Param = id:Identifier _ ":" _ t:Type { return mapType(t)+" "+id; }
IdentifierList = head:Identifier tail:(_ "," _ Identifier)* { return [head].concat(tail.map(t=>t[3])); }

/* --- Expressions --- */
Expression = Comparison
Comparison = left:AddSub tail:(_ CompOp _ AddSub)* { return tail.reduce((acc,t)=>acc+" "+t[1]+" "+t[3], left); }
CompOp = "==" / "!=" / "<=" / ">=" / "<" / ">"
AddSub = left:MulDiv tail:(_ ("+" / "-") _ MulDiv)* { return tail.reduce((acc,t)=>acc+" "+t[1]+" "+t[3], left); }
MulDiv = left:Power tail:(_ ("*" / "/") _ Power)* { return tail.reduce((acc,t)=>acc+" "+t[1]+" "+t[3], left); }

/* --- Power converted to pow() --- */
Power = left:Unary tail:(_ "**" _ Unary)* { return tail.reduce((acc,t) => "pow("+acc+", "+t[3]+")", left); }

Unary = "-" _ v:Unary { return "-"+v; } / UpdateExpr / Ternary / Primary
UpdateExpr = id:Assignable op:("++" / "--") { return id+op; }
Ternary = cond:Primary _ "?" _ tExpr:Expression _ ":" _ fExpr:Expression { return cond+" ? "+tExpr+" : "+fExpr; }

/* --- Primary expressions --- */
Primary = "(" _ e:Expression _ ")" { return "("+e+")"; } / ArrayLiteral / MathCall / FuncCall / StructConstructor / Assignable / IdentifierDot / StringLiteral / Identifier / Number
StructConstructor = id:Identifier "(" _ args:ArgList? _ ")" { return id+"("+(args?args.join(","):"")+")"; }

/* --- Arrays --- */
ArrayLiteral = "[" _ elements:ExprList _ "]" { return {type:"array", elements: elements}; }
ExprList = head:Expression tail:(_ "," _ Expression)* { return [head].concat(tail.map(t=>t[3])); }

/* --- Math calls --- */
MathCall = "Math" _ "." _ fname:Identifier "(" _ args:ArgList? _ ")" { return mapFunc("Math."+fname+"("+((args||[]).join(","))+")"); }
FuncCall = id:Identifier "(" _ args:ArgList? _ ")" { return id+"("+(args?args.join(","):"")+")"; }
ArgList = head:Expression tail:(_ "," _ Expression)* { return [head].concat(tail.map(t=>t[3])); }

/* --- Identifiers and dot-access (constants handled) --- */
Identifier = id:$([a-zA-Z_$][a-zA-Z0-9_$]*) { return id; }

IdentifierDot = left:Identifier "." right:Identifier {
  const full = left + "." + right;
  if(jsConstMap[full]) return jsConstMap[full];
  const l = glslBuiltIns.includes(left) ? left : left+"_compiled";
  const r = glslBuiltIns.includes(right) ? right : right+"_compiled";
  return l + "." + r;
}

/* --- Classes --- */
ClassDecl = "class" __ id:Identifier _ "{" _ fields:(ClassField (_ ClassField)*)? _ "}" { const allFields = fields ? [fields[0]].concat(fields[1].map(t=>t[1])) : []; const members = allFields.map(f => mapType(f.type)+" "+f.name+";").join("\n"); return "typedef struct {\n"+members+"\n} "+id+";\n"; }
ClassField = _ id:Identifier _ ":" _ t:Type _ ";" { return {name:id, type:t}; }

/* --- Types --- */
Type = base:BaseType arr:("[]")* { return base+arr.join(""); }
BaseType = "number" / "boolean" / "vec2" / "vec3" / "vec4" / "string" / Identifier

/* --- Assignable --- */
Assignable = base:IdentifierOrCall tail:(_ AccessPart)* { let compiledBase = typeof base === "string" ? base : base; return tail.reduce((acc,t)=>{ const p = t[1]; if(p.type === "member") return acc + "." + p.name; else return acc + "[" + p.index + "]"; }, compiledBase); }
IdentifierOrCall = StructConstructor / FuncCall / IdentifierDot / Identifier
AccessPart = "." name:Identifier { return {type:"member", name}; } / "[" _ idx:Expression _ "]" { return {type:"index", index:idx}; }

/* --- String literals --- */
StringLiteral = s:$("\"" ([^\"]*) "\"") { return stringToFloatArray(s); }

/* --- Expression statements --- */
ExprStmt = expr:Expression _ ";" { return expr+";"; }

/* --- Numbers --- */
Number = n:$([0-9]+ ("." [0-9]+)?) { return formatNumber(text()); }

/* --- Whitespace --- */
_ = [ \t\r\n]*
__ = [ \t\r\n]+
