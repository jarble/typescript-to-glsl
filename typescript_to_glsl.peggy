{
  const typeMap = { 
    number: "float", 
    boolean: "bool", 
    vec2: "vec2", 
    vec3: "vec3", 
    vec4: "vec4", 
    string: "float[]"    // convert TypeScript string to GLSL float[]
  };

  const jsFuncMap = {
    "Math.abs":"abs","Math.acos":"acos","Math.asin":"asin","Math.atan":"atan",
    "Math.atan2":"atan","Math.ceil":"ceil","Math.cos":"cos","Math.exp":"exp",
    "Math.floor":"floor","Math.log":"log","Math.max":"max","Math.min":"min",
    "Math.pow":"pow","Math.sin":"sin","Math.sqrt":"sqrt","Math.tan":"tan"
  };

  const jsConstMap = { "Math.PI": "3.141592653589793", "Math.E": "2.718281828459045" };

  const glslBuiltIns = ["abs","acos","asin","atan","ceil","cos","exp","floor","log",
                        "max","min","pow","sin","sqrt","tan","mod","clamp","mix",
                        "step","smoothstep","length","normalize","dot","cross"];

  function mapType(tsType){ 
    if(!tsType) return "float"; 
    if(tsType.endsWith("[]")) return mapType(tsType.slice(0,-2))+"[]"; 
    return typeMap[tsType] || tsType; 
  }

  function mapFunc(expr){ 
    for(const k in jsFuncMap){ 
      if(expr.startsWith(k+"(")){ 
        const args=expr.slice(k.length+1,expr.length-1); 
        return jsFuncMap[k]+"("+args+")"; 
      } 
    } 
    if(jsConstMap[expr]) return jsConstMap[expr]; 
    return expr; 
  }

  function flatten2DArray(elements){ 
    const rows=elements.map(e=>e.slice(8,-1).split(",")); 
    const rowCount=rows.length; 
    const colCount=rows[0].length; 
    if(rowCount===colCount) return "mat"+rowCount+"("+rows.flat().join(",")+")"; 
    return "float[]("+elements.join(",")+")"; 
  }

  function emitComment(c){ return c+"\n"; }
  function emitConst(id,expr){ return "#define "+id+" "+expr+"\n"; }

  function compileIdent(id){
    if(glslBuiltIns.includes(id) || id.endsWith("_compiled")) return id;
    return id+"_compiled";
  }

  function formatNumber(n){
    return n.includes(".") ? n : n+".0";
  }

  function stringToFloatArray(str){
    let s = str.slice(1,-1); // remove quotes
    return "float[](" + Array.from(s).map(c => c.charCodeAt(0)+".0").join(",") + ")";
  }
}

/* --- Start --- */
Start
  = _ items:(TopLevelItem (_ TopLevelItem)*)? _ {
      let all = items ? [items[0]].concat(items[1].map(t=>t[1])) : [];
      return all.map(s=>s.replace(/;/g,";\n")).join("");
    }

/* --- Top-level items --- */
TopLevelItem
  = CommentStmt
  / ClassDecl
  / FunctionDecl
  / JSFunction
  / ConstDecl
  / TopLevelVarDecl
  / AssignmentStmt
  / ForStmt
  / WhileStmt
  / DoWhileStmt
  / SwitchStmt

/* --- Statements inside functions --- */
Statement
  = CommentStmt
  / AssignmentStmt
  / VarDeclTyped
  / ReturnStmt
  / IfStmt
  / ExprStmt
  / Block
  / ForStmt
  / WhileStmt
  / DoWhileStmt
  / SwitchStmt

/* --- Comments --- */
CommentStmt
  = c:Comment { return emitComment(c); }
Comment
  = SingleLineComment / MultiLineComment
SingleLineComment
  = c:$("//" [^\r\n]*) { return c; }
MultiLineComment
  = c:$("/*" (!"*/" .)* "*/") { return c; }

/* --- Constants --- */
ConstDecl
  = "const" __ id:Identifier _ "=" _ expr:(ArrayLiteral / MathCall / Number / StringLiteral / Assignable) _ ";" { return emitConst(id,expr); }

/* --- Functions --- */
FunctionDecl
  = "function" __ id:Identifier _ "(" _ params:ParamList? _ ")" _ ":" _ ret:Type _ _ body:Block {
      const ps = params ? params.join(", "):""; 
      return mapType(ret)+" "+id+"("+ps+") "+body;
    }

JSFunction
  = "function" __ id:Identifier _ "(" _ params:IdentifierList? _ ")" _ "{" _ body:MacroBody _ "}" {
      const ps = params?params.join(","):""; 
      return "#define "+id+"("+ps+") "+body+"\n";
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

/* --- Variable Declarations --- */
TopLevelVarDecl
  = ("var"/"let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" { return mapType(t)+" "+id+" = "+expr+";"; }
  / ("var"/"let") __ id:Identifier _ "=" _ expr:Expression _ ";" { return emitConst(id,expr); }

VarDeclTyped
  = ("var"/"let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression _ ";" { return mapType(t)+" "+id+" = "+expr+";"; }

/* --- Variable/assignment without semicolon for for-loop --- */
VarDeclTypedNoSemi
  = ("var" / "let") __ id:Identifier _ ":" _ t:Type _ "=" _ expr:Expression { return mapType(t) + " " + id + " = " + expr; }
AssignmentNoSemi
  = id:Assignable _ op:AssignOp _ expr:Expression { return id + " " + op + " " + expr; }

/* --- Assignments --- */
AssignmentStmt
  = id:Assignable _ op:AssignOp _ expr:Expression _ ";" { return id+" "+op+" "+expr+";"; }
AssignOp
  = "+=" / "-=" / "*=" / "/=" / "="

/* --- Return --- */
ReturnStmt
  = "return" __ expr:Expression _ ";" { return "return "+expr+";"; }

/* --- If / else if / else --- */
IfStmt
  = "if" _ "(" _ cond:Expression _ ")" _ then:Block _ elsePart:ElseClause? { return "if("+cond+") "+then+(elsePart?" "+elsePart:""); }
ElseClause
  = "else" _ stmt:(IfStmt / Block) { return "else "+stmt; }

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
  = "for" _ "(" _ init:(VarDeclTypedNoSemi / AssignmentNoSemi / Expression)? _ ";" _ cond:Expression? _ ";" _ update:(UpdateExpr / AssignmentNoSemi / Expression)? _ ")" _ body:Block {
      return "for("+(init||"")+";"+(cond||"")+";"+(update||"")+") "+body;
    }

WhileStmt
  = "while" _ "(" _ cond:Expression _ ")" _ body:Block { return "while("+cond+") "+body; }

DoWhileStmt
  = "do" _ body:Block _ "while" _ "(" _ cond:Expression _ ")" _ ";" { return "do "+body+" while("+cond+");"; }

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
CompOp = "==" / "!=" / "<=" / ">=" / "<" / ">" / "<"
AddSub = left:MulDiv tail:(_ ("+" / "-") _ MulDiv)* { return tail.reduce((acc,t)=>acc+" "+t[1]+" "+t[3], left); }
MulDiv = left:Unary tail:(_ ("*" / "/") _ Unary)* { return tail.reduce((acc,t)=>acc+" "+t[1]+" "+t[3], left); }

/* --- Unary / Update --- */
Unary
  = "-" _ v:Unary { return "-"+v; }
  / UpdateExpr
  / Primary

UpdateExpr
  = id:Assignable op:("++" / "--") { return id+op; }

/* --- Primary expressions --- */
Primary
  = "(" _ e:Expression _ ")" { return "("+e+")"; }
  / ArrayLiteral
  / MathCall
  / FuncCall
  / StructConstructor
  / Assignable
  / IdentifierDot
  / StringLiteral
  / Identifier
  / Number

StructConstructor
  = id:Identifier "(" _ args:ArgList? _ ")" { 
      return id+"("+(args?args.join(","):"")+")"; 
    }

/* --- Arrays --- */
ArrayLiteral
  = "[" _ elements:ExprList _ "]" { 
      if(elements.length>0 && elements.every(e=>typeof e==="string" && e.startsWith("float[]("))) return flatten2DArray(elements); 
      else return "float[]("+elements.join(",")+")"; 
    }

ExprList
  = head:Expression tail:(_ "," _ Expression)* { return [head].concat(tail.map(t=>t[3])); }

/* --- Math calls (fixed whitespace around dot) --- */
MathCall
  = "Math" _ "." _ fname:Identifier "(" _ args:ArgList? _ ")" { 
      return mapFunc("Math."+fname+"("+((args||[]).join(","))+")"); 
    }

/* --- Function calls --- */
FuncCall
  = id:Identifier "(" _ args:ArgList? _ ")" { return id+"("+(args?args.join(","):"")+")"; }

ArgList
  = head:Expression tail:(_ "," _ Expression)* { return [head].concat(tail.map(t=>t[3])); }

IdentifierDot = left:Identifier "." right:Identifier { return left + "." + right; }

/* --- Classes --- */
ClassDecl
  = "class" __ id:Identifier _ "{" _ fields:(ClassField (_ ClassField)*)? _ "}" {
      const allFields = fields ? [fields[0]].concat(fields[1].map(t=>t[1])) : [];
      const members = allFields.map(f => mapType(f.type)+" "+f.name+";").join("\n");
      return "typedef struct {\n"+members+"\n} "+id+";\n";
    }

ClassField
  = _ id:Identifier _ ":" _ t:Type _ ";" { return {name:id, type:t}; }

/* --- Types --- */
Type = base:BaseType arr:("[]")* { return base+arr.join(""); }
BaseType = "number" / "boolean" / "vec2" / "vec3" / "vec4" / "string" / Identifier

/* --- Assignable expressions --- */
Assignable
  = base:IdentifierOrCall tail:(_ AccessPart)* {
      let compiledBase = typeof base === "string" ? base : base;
      return tail.reduce((acc,t)=>{
        const p = t[1];
        if(p.type === "member") return acc + "." + p.name;
        else return acc + "[" + p.index + "]";
      }, compiledBase);
    }

IdentifierOrCall
  = StructConstructor
  / FuncCall
  / IdentifierDot
  / Identifier

AccessPart
  = "." name:Identifier { return {type:"member", name}; }
  / "[" _ idx:Expression _ "]" { return {type:"index", index:idx}; }

/* --- String literals --- */
StringLiteral
  = s:$("\"" ([^\"]*) "\"") { return stringToFloatArray(s); }

/* --- Tokens --- */
Identifier = $([a-zA-Z_$][a-zA-Z0-9_$]*) { return compileIdent(text()); }
Number = $([0-9]+ ("." [0-9]+)?) { return formatNumber(text()); }
_ = [ \t\r\n]*
__ = [ \t\r\n]+
