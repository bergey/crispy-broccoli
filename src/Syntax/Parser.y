{
{-# LANGUAGE DuplicateRecordFields #-}
module Syntax.Parser where

import Syntax.Untyped
import Syntax.Internal (mkName)
import Syntax.Lex (Alex, LocToken(..), Token)

import           Prelude hiding (LT, GT, lex)
import           Data.List.NonEmpty        (NonEmpty (..))

import qualified Syntax.Lex as L
import qualified Data.List.NonEmpty as NE
}

%name parseQuery_ Query
%name parseCondition_ Condition
%name parseExpr_ Expr
%tokentype { L.LocToken }
%monad { Alex }
%lexer { lexwrap } {  L.LocToken _ L.EOF }
%error { happyError }

%left or
%left and
%right not
%right '='
%left '<' '>'
%nonassoc like ilike
%left '!=' '<=' '>='
%nonassoc notnull
%nonassoc isnull
%nonassoc is
%left '+' '-'
%left '*' '/'
%left '^'

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
    number { LocToken _ (L.Number $$) }
    param { LocToken _ (L.Param $$) }

    '*' { LocToken _ L.Mul }
    '/' { LocToken _ L.Div }
    '+' { LocToken _ L.Add }
    '-' { LocToken _ L.Sub }
    '^' { LocToken _ L.Exponent }

    is { LocToken _ L.Is }
    null { LocToken _ L.Null }
    isnull { LocToken _ L.IsNull }
    notnull { LocToken _ L.NotNull }

    '=' { LocToken _ L.Equals }
    '!=' { LocToken _ L.NotEquals }
    '<' { L.LocToken _ L.LT }
    '>' { L.LocToken _ L.GT }
    '<=' { L.LocToken _ L.LTE }
    '>=' { L.LocToken _ L.GTE }
    not { L.LocToken _ L.Not }
    like { L.LocToken _ L.Like }
    ilike { L.LocToken _ L.ILike }

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
    : select ExprList from Name where Condition { Select { table = $4, columns = NE.fromList (reverse $2), conditions = Just $6 } }
    | select ExprList from Name { Select { table = $4, columns = NE.fromList (reverse $2), conditions = Nothing } }

Insert : insert into Name '(' NameList ')' values '(' ExprList ')'
       { Insert { table = $3, columns = NE.fromList (reverse $5), values = NE.fromList (reverse $9) } }

{- These lists are non-empty by construction, but not by type. List head is the right-most element. -}

NameList
    : Name { [$1] }
    | NameList comma Name { $3 : $1 }

ExprList
    : Expr { [$1] }
    | ExprList comma Expr { $3 : $1 }

Compare :: { Compare }
    : '=' { Eq }
    | '!=' { NEq }
    | '<' { LT }
    | '>' { GT }
    | '<=' { LTE }
    | '>=' { GTE }
    | like { Like }
    | ilike { ILike }

Condition
    : Name Compare Expr { Compare $2 $1 $3 }
    | Condition and Condition { And $1 $3 }
    | Condition or Condition { Or $1 $3 }
    | not Condition { Not $2 }
    | '(' Condition ')' { $2 }

Name : name { mkName $1 }

Expr :: { Expr }
    : Literal { Lit $1 }
    | Name { Var $1 }
    | param { Param $1 }
    | '(' Expr ')' { $2 }
    | Expr '^' Expr { BinOp Exponent $1 $3 }
    | Expr '*' Expr { BinOp Mul $1 $3 }
    | Expr '/' Expr { BinOp Div $1 $3 }
    | Expr '+' Expr { BinOp Add $1 $3 }
    | Expr '-' Expr { BinOp Sub $1 $3 }
    | Expr '=' Expr { BinOp (Comp  Eq) $1 $3 }
    | Expr '!=' Expr { BinOp (Comp  NEq) $1 $3 }
    | Expr '<' Expr { BinOp (Comp  LT) $1 $3 }
    | Expr '>' Expr { BinOp (Comp  GT) $1 $3 }
    | Expr '<=' Expr { BinOp (Comp  LTE) $1 $3 }
    | Expr '>=' Expr { BinOp (Comp  GTE) $1 $3 }
    | Expr like Expr { BinOp (Comp  Like) $1 $3 }
    | Expr ilike Expr { BinOp (Comp  ILike) $1 $3 }
    | not Expr { Unary NegateBool $2 }
    | '-' Expr { Unary NegateNum $2 }
    | Expr Null { Unary $2 $1 }

Literal
        : string { T $1 }
        | number { F $1 }

Null
        : is null { IsNull }
        | isnull { IsNull }
        | is not null { NotNull }
        | notnull { NotNull }


{

-- from https://github.com/dagit/happy-plus-alex/blob/master/src/Parser.y

lexwrap :: (L.LocToken -> Alex a) -> Alex a
lexwrap = (L.alexMonadScan' >>=)

happyError :: L.LocToken -> Alex a
happyError (L.LocToken p t) =
  L.alexError' p ("parse error at token '" ++ L.unLex t ++ "'")

parseQuery :: FilePath -> String -> Either String Query
parseQuery = L.runAlex' parseQuery_

parseCondition :: FilePath -> String -> Either String Condition
parseCondition = L.runAlex' parseCondition_

parseExpr :: FilePath -> String -> Either String Expr
parseExpr = L.runAlex' parseExpr_

}
