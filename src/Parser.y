{
{-# LANGUAGE DuplicateRecordFields #-}
module Parser where

import Syntax
import Internal (mkName)
import Lex (Alex, LocToken(..), Token)

import           Data.List.NonEmpty        (NonEmpty (..))

import qualified Lex as L
import qualified Data.List.NonEmpty as NE
}

%name parse
%tokentype { L.LocToken }
%monad { Alex }
%lexer { lexwrap } {  L.LocToken _ L.EOF }
%error { happyError }

%left and
%left or

%token
    delete { LocToken _ L.Delete }
    select { LocToken _ L.Select }
    insert { LocToken _ L.Insert }

    from { LocToken _ L.From }
    where { LocToken _ L.Where }
    into { LocToken _ L.Into }
    values { LocToken _ L.Values }
    '(' { LocToken _ L.LParen }
    ')' { LocToken _ L.RParen }
    comma { LocToken _ L.Comma }

    name { LocToken _ (L.Name $$) }
    string { LocToken _ (L.String $$) }

    '=' { LocToken _ L.Equals }
    '!=' { LocToken _ L.NotEquals }

    and  { LocToken _ L.And }
    or { LocToken _ L.Or }

%%

Query
    : Delete { QD $1 }
    | Select { QS $1 }
    | Insert { QI $1 }

Delete
    : delete from Name where Condition { Delete $3 (Just $5) }
    | delete from Name { Delete $3 Nothing }

Select
    : select NameList from Name where Condition { Select { table = $4, columns = NE.fromList (reverse $2), conditions = Just $6 } }
    | select NameList from Name { Select { table = $4, columns = NE.fromList (reverse $2), conditions = Nothing } }

Insert : insert into Name '(' NameList ')' values '(' LitList ')'
       { Insert { table = $3, columns = NE.fromList (reverse $5), values = NE.fromList (reverse $9) } }

{- These lists are non-empty by construction, but not by type. List head is the right-most element. -}

NameList
    : Name { [$1] }
    | NameList comma Name { $3 : $1 }

ExprList
    : Expr { [$1] }
    | ExprList comma Expr { $3 : $1 }

LitList
    : Literal { [$1] }
    | LitList comma Literal { $3 : $1 }

Operator
    : '=' { Eq }
    | '!=' { NEq }

Condition
    : Name Operator Expr { Op $2 $1 $3 }
    | Condition and Condition { And $1 $3 }
    | Condition or Condition { Or $1 $3 }

Name : name { mkName $1 }

Expr
    : Literal { Lit $1 }
    | Name { Var $1 }
    | '(' Expr ')' { $2 }

Literal : string { T $1 }

{

lexwrap :: (L.LocToken -> Alex a) -> Alex a
lexwrap = (L.alexMonadScan' >>=)

happyError :: L.LocToken -> Alex a
happyError (L.LocToken p t) =
  L.alexError' p ("parse error at token '" ++ L.unLex t ++ "'")

parseExp :: FilePath -> String -> Either String Query
parseExp = L.runAlex' parse

}
