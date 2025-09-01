{
  const jsToGlslFuncMap = {
    "Math.abs": "abs",
    "Math.acos": "acos",
    "Math.acosh": "acosh",
    "Math.asin": "asin",
    "Math.asinh": "asinh",
    "Math.atan": "atan",
    "Math.atan2": "atan",
    "Math.atanh": "atanh",
    "Math.cbrt": "pow",
    "Math.ceil": "ceil",
    "Math.cos": "cos",
    "Math.cosh": "cosh",
    "Math.exp": "exp",
    "Math.expm1": "exp(x)-1.0",
    "Math.floor": "floor",
    "Math.hypot": "length",
    "Math.log": "log",
    "Math.log1p": "log(1.0 + x)",
    "Math.log2": "log2",
    "Math.log10": "log10",
    "Math.max": "max",
    "Math.min": "min",
    "Math.pow": "pow",
    "Math.sign": "sign",
    "Math.sin": "sin",
    "Math.sinh": "sinh",
    "Math.sqrt": "sqrt",
    "Math.tan": "tan",
    "Math.tanh": "tanh",
    "Math.trunc": "trunc"
  };

  function mapFunc(expr){
    for(const key in jsToGlslFuncMap){
      const pattern = key + "(";
      if(expr.startsWith(pattern)){
        const args = expr.slice(pattern.length, expr.length-1);
        if(key === "Math.cbrt") return "pow(" + args + ", 1.0/3.0)";
        if(key === "Math.expm1") return "(exp(" + args + ")-1.0)";
        if(key === "Math.log1p") return "(log(1.0 + " + args + "))";
        if(key === "Math.hypot") return "length(vec2(" + args + "))";
        if(key === "Math.atan2") return "atan(" + args + ")";
        return jsToGlslFuncMap[key]+"("+args+")";
      }
    }
    return expr;
  }

  function emit(node){
    if(node.type === "return") return mapExpr(node.expr);
    if(node.type === "if"){
      const cond = mapExpr(node.cond);
      const thenExpr = emit(node.then);
      const elseExpr = emit(node.else);
      return "(" + cond + " ? " + thenExpr + " : " + elseExpr + ")";
    }
    if(node.type === "var") return "#define " + node.name + " " + mapExpr(node.value);
    return "";
  }

  function mapExpr(expr){
    return mapFunc(expr);
  }

  function makeMacroFromFunc(name, params, body){
    return "#define " + name + "(" + (params||[]).join(", ") + ") " + emit(body);
  }

  function flatten2DArray(elements){
    // elements is an array of strings: "float[](1,2)"
    const rows = elements.map(e => e.slice(8,-1).split(","));
    const rowCount = rows.length;
    const colCount = rows[0].length;
    if(rowCount === colCount){
      const flatElements = rows.flat().join(",");
      return "mat" + rowCount + "(" + flatElements + ")";
    }
    return "/* Only square 2D arrays supported for matN */";
  }
}

Start
  = _ items:(TopLevelItem (_ TopLevelItem)*) _ {
      return [items[0]].concat(items[1].map(t => t[1]))
                       .map(item => item.type === "func" ? makeMacroFromFunc(item.name, item.params, item.body) : emit(item))
                       .join("\n");
    }

TopLevelItem
  = GlobalVar
  / FunctionDef

GlobalVar
  = ("var" / "let") WS name:Identifier _ "=" _ value:Expr _ ";" { return {type:"var", name, value}; }

FunctionDef
  = "function" _ name:Identifier _ "(" _ params:ParamList? _ ")" _ "{" _ body:FunctionBody _ "}" { 
      return {type:"func", name, params: params||[], body}; 
    }

ParamList
  = head:Identifier tail:(_ "," _ Identifier)* { return [head].concat(tail.map(t=>t[3])); }

FunctionBody
  = IfReturnStmt
  / ReturnStmt

ReturnOrBlock
  = "{" _ stmt:ReturnStmt _ "}" { return stmt; }
  / ReturnStmt

IfReturnStmt
  = "if" _ "(" _ cond:Expr _ ")" _ thenBody:ReturnOrBlock _ elsePart:ElseClause {
      return {type:"if", cond, then: thenBody, else: elsePart};
    }

ElseClause
  = "else" _ stmt:IfReturnStmt { return stmt; }
  / "else" _ stmt:ReturnOrBlock { return stmt; }

ReturnStmt
  = "return" WS expr:Expr _ ";" { return {type:"return", expr}; }

Expr
  = Comparison

Comparison
  = left:AddSub _ op:CompOp _ right:AddSub { return left + " " + op + " " + right; }
  / AddSub

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
  / Identifier
  / Number

ArrayLiteral
  = "[" _ elements:ExprList _ "]" {
      // check if elements are array literals themselves for 2D array
      if(elements.length > 0 && elements.every(e => typeof e === "string" && e.startsWith("float[]("))){
        return flatten2DArray(elements);
      } else {
        return "float[](" + elements.join(",") + ")";
      }
    }

ExprList
  = head:Expr tail:(_ "," _ Expr)* { return [head].concat(tail.map(t=>t[3])); }

FuncCall
  = id:Identifier "(" _ args:FuncArgs? _ ")" { 
      const argText = args ? args.join(",") : "";
      return id + "(" + argText + ")";
    }

FuncArgs
  = head:Expr tail:(_ "," _ Expr)* { return [head].concat(tail.map(t=>t[3])); }

ParenExpr
  = "(" _ e:Expr _ ")" { return "(" + e + ")"; }

Identifier
  = $([a-zA-Z_$][a-zA-Z0-9_$]* ("." [a-zA-Z_$][a-zA-Z0-9_$]*)*)

Number
  = $([0-9]+ ("." [0-9]+)?)

WS = [ \t\r\n]+

_ = [ \t\r\n]*
