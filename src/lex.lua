globals("linebreak_finder", "lex")

local lpeg = require "lpeg"
local C,Cp,Ct,Cc,S,P,R,V = lpeg.C,lpeg.Cp,lpeg.Ct,lpeg.Cc,lpeg.S,lpeg.P,lpeg.R,lpeg.V

linebreak_finder = P(1 - (P"\r\n" + P"\n" + P"\r"))^0 * (P"\r\n" + P"\n" + P"\r") * Cp();

lex = P{
   V"eof" + V"token";
   eof = V"prespace" * P(-1) * Cc("eof");
   token = V"prespace" * (V"comment" + V"directive" + V"identifier" + V"number"
                             + V"char_literal" + V"string_literal"
                             + V"punctuator" + V"unknown_char") * V"postspace";
   prespace = C((V"whitespace" - V"linebreak")^0) * Cp();
   postspace = C(V"whitespace"^0) * Cp();
   comment = Cc("comment") * C(V"sl_comment" + V"ml_comment");
   sl_comment = P"//" * (1 - V"linebreak")^0;
   ml_comment = P"/*" * (1 - P"*/")^0;
   directive = Cc"directive" * C(P"#" * (P"\\"*V"linebreak" + (1 - V"linebreak"))^0);
   identifier = Cc"identifier" * C(R("__","az","AZ")*R("__","az","AZ","09")^0),
   number = Cc"number" * C(R"09" * (R("09","AF","af")+S".xulXUL+-")^0),
   whitespace = S" \t\v\n\f\r";
   linebreak = P"\r\n" + P"\n" + P"\r";
   char_literal = Cc"literal" * C(P"'" * (V"literal_el" - P"'")^0 * P"'");
   string_literal = Cc"literal" * C(P'"' * (V"literal_el" - P'"')^0 * P'"');
   literal_el = (P"\\" * (P"x" * R("09","AF","af")^1
                             + (R"07" * R"07"^-2)
                             + 1)) + 1;
   punctuator = Cc"punctuator" * C(P"->"+P"++"+P"--"+P"<<="+P">>="+P"<="+P">="
                                      +P"=="+P"!="+P"&&"+P"||"+P"*="+P"/="
                                      +P"%="+P"+="+P"-="+P"<<"+P">>"+P"&="
                                      +P"^="+P"|="
                                      +S"[](){}.&*+-~!/%<>^|?:;=,");
   unknown_char = Cc"unknown_char" + C(1);
}
