{
  const typeMap = {
    "number": "float",
    "boolean": "bool",
    "vec2": "vec2",
    "vec3": "vec3",
    "vec4": "vec4",
    "mat2": "mat2",
    "mat3": "mat3",
    "mat4": "mat4"
  };
  function mapType(tsType) { return typeMap[tsType] || "float"; }

  const jsToGlslFuncMap = {
    "Math.abs": "abs","Math.acos": "acos","Math.asin": "asin","Math.atan": "atan",
    "Math.atan2": "atan","Math.ceil": "ceil","Math.cos": "cos","Math.exp": "exp",
    "Math.floor": "floor","Math.log": "log","Math.max": "max","Math.min": "min",
    "Math.pow": "pow","Math.sin": "sin","Math.sqrt": "sqrt","Math.tan": "tan"
  };

  function mapFunc(expr){
    for(const key in jsToGlslFuncMap){
      const pattern = key + "(";
      if(expr.startsWith(pattern)){
        const args = expr.slice(pattern.length, expr.length-1);
        return jsToGlslFuncMap[key] + "(" + args + ")";
      }
    }
    return expr;
  }

  function flatten2DArray(elements){
    const rows = elements.map(e => e.slice(8,-1).split(","));
    const rowCount = rows.length;
    const colCount = rows[0].length;
    if(rowCount === colCount){
      return "mat" + rowCount + "(" + rows.flat().join(",") + ")";
    }
    return "float[](" + elements.join(",") + ")";
  }

  function emit(node){
    if(typeof node === "string") return node;
    switch(node.type){
      case "var": return "#define " + node.name + " " + mapFunc(node.value);
      case "localVar": return mapType(node.varType || "number") + " " + node.name + " = " + mapFunc(node.value) + ";";
      case "glslFunc":
        const retType = mapType(node.returnType || "number");
        const params = node.params.map(p => mapType(p.type) + " " + p.name).join(", ");
        return retType + " " + node.name + "(" + params + ") {\n" + node.body.map(emit).join("\n") + "\n}";
      case "macroFunc":
        const paramList = node.params.join(",");
        return "#define " + node.name + "(" + paramList + ") " + mapFunc(node.body);
      case "return": return "return " + mapFunc(node.expr) + ";";
      case "if": return "if(" + mapFunc(node.cond) + ") " + emit(node.then) + (node.else ? " else " + emit(node.else) : "");
      case "for": return "for(" + (node.init||"") + ";" + (node.cond||"") + ";" + (node.update||"") + ") {" + node.body.map(emit).join("\n") + "}";
      case "while": return "while(" + mapFunc(node.cond) + ") {" + node.body.map(emit).join("\n") + "}";
      case "block": return "{\n" + node.body.map(emit).join("\n") + "\n}";
      default: return "";
    }
  }
}

Start
  = _ items:(TopLevelItem (_ TopLevelItem)*) _ { return [items[0]].concat(items[1].map(t=>t[1])).map(emit).join("\n"); }

TopLevelItem
  = GlobalVar / FunctionDef

GlobalVar
  = ("var" / "let") WS name:Identifier _ t:(":" _ type:Identifier)? _ "=" _ value:Expr _ ";" { 
      return {type:"var", name, value, varType:t ? t[2] : undefined}; 
    }

FunctionDef
  = TSFunction / JSFunction

TSFunction
  = "function" _ name:Identifier _ "(" _ params:TypedParamList? _ ")" _ returnType:ReturnType? _ "{" _ body:Statement* _ "}" {
      return {type:"glslFunc", name, params:params||[], returnType:returnType, body:body};
    }

JSFunction
  = "function" _ name:Identifier _ "(" _ params:IdentifierList? _ ")" _ "{" _ body:MacroBody _ "}" {
      return {type:"macroFunc", name, params:params||[], body:body};
    }

MacroBody
  = "return" WS expr:Expr _ ";" { return expr; }

TypedParamList
  = head:TypedParam tail:(_ "," _ TypedParam)* { return [head].concat(tail.map(t=>t[3])); }

TypedParam
  = name:Identifier _ ":" _ type:Identifier { return {name,type}; }

ReturnType
  = ":" _ type:Identifier { return type; }

IdentifierList
  = head:Identifier tail:(_ "," _ Identifier)* { return [head].concat(tail.map(t=>t[3])); }

Statement
  = ReturnStmt / IfStmt / ForStmt / WhileStmt / LocalVarDecl / BlockStmt / ExprStmt

LocalVarDecl
  = ("var" / "let") WS name:Identifier _ t:(":" _ type:Identifier)? _ "=" _ value:Expr _ ";" { 
      return {type:"localVar", name, varType:t ? t[2] : undefined, value}; 
    }

BlockStmt
  = "{" _ stmts:Statement* _ "}" { return {type:"block", body:stmts}; }

ReturnStmt
  = "return" WS expr:Expr _ ";" { return {type:"return", expr}; }

IfStmt
  = "if" _ "(" _ cond:Expr _ ")" _ thenStmt:Statement _ elseStmt:ElseClause? { return {type:"if", cond, then:thenStmt, else:elseStmt}; }

ElseClause
  = "else" _ stmt:Statement { return stmt; }

ForStmt
  = "for" _ "(" _ init:Expr? _ ";" _ cond:Expr? _ ";" _ update:Expr? _ ")" _ body:Statement { return {type:"for", init:init, cond:cond, update:update, body:[body]}; }

WhileStmt
  = "while" _ "(" _ cond:Expr _ ")" _ body:Statement { return {type:"while", cond, body:[body]}; }

ExprStmt
  = expr:Expr _ ";" { return expr; }

Expr
  = Comparison

Comparison
  = left:AddSub _ op:CompOp _ right:AddSub { return left + " " + op + " " + right; } / AddSub

CompOp
  = ">" / "<" / "==" / "!="

AddSub
  = head:MulDiv tail:(_ ("+" / "-") _ MulDiv)* { return tail.reduce((acc,e)=>acc+e[1]+e[3], head); }

MulDiv
  = head:Primary tail:(_ ("*" / "/") _ Primary)* { return tail.reduce((acc,e)=>acc+e[1]+e[3], head); }

Primary
  = ArrayLiteral
  / FuncCall
  / ParenExpr
  / Number
  / IdentifierDot
  / Identifier

ArrayLiteral
  = "[" _ elements:ExprList _ "]" {
      if(elements.length>0 && elements.every(e=>typeof e==="string" && e.startsWith("float[]("))){
        return flatten2DArray(elements);
      } else {
        return "float[](" + elements.join(",") + ")";
      }
    }

ExprList
  = head:Expr tail:(_ "," _ Expr)* { return [head].concat(tail.map(t=>t[3])); }

FuncCall
  = id:(Identifier / IdentifierDot) "(" _ args:FuncArgs? _ ")" { 
      const argText = args ? args.join(",") : ""; 
      return mapFunc(id + "(" + argText + ")"); 
    }

FuncArgs
  = head:Expr tail:(_ "," _ Expr)* { return [head].concat(tail.map(t=>t[3])); }

ParenExpr
  = "(" _ e:Expr _ ")" { return "(" + e + ")"; }

IdentifierDot
  = left:Identifier "." right:Identifier { return left + "." + right; }

Identifier
  = $([a-zA-Z_$][a-zA-Z0-9_$]*)

Number
  = $([0-9]+ ("." [0-9]+)?)

WS = [ \t\r\n]+
_ = [ \t\r\n]*
