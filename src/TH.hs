{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE TemplateHaskell #-}
module TH where

import Syntax.Untyped as Syntax
import Syntax.Parser (parseQuery)
import TypedQuery

import Data.String (IsString(..))
import Database.PostgreSQL.Simple (Only(..))
import Language.Haskell.TH
import Language.Haskell.TH.Quote
import Language.Haskell.TH.Syntax (Lift(..))

a1Names :: Int -> [String]
a1Names n = take n names where
  names = [c : "" | c <- ['a'..'z']] ++ [ c : show i | i <- [1..], c <- ['a'..'z'] ]

cNames :: Char -> Int -> Q [Name]
cNames c n = traverse newName [c : show i | i <- [1..n] ]

tupleType :: [Name] -> Type
tupleType [v] = AppT (ConT ''Only) (VarT v)
tupleType names = foldl (\expr v -> AppT expr (VarT v)) (TupleT n) names
    where n = length names

-- | Synthesize a TypedQuery tagged with tuples of the given size
makeArityQuery :: String -> Query -> Word -> Int -> Q Exp
makeArityQuery raw parsed p r =
    [e|TypedQuery raw parsed :: TypedQuery params result |]
    where
        params = tupleType <$> cNames 'p' (fromIntegral p)
        result = tupleType <$> cNames 'r' r

aritySql :: QuasiQuoter
aritySql = QuasiQuoter
    { quoteExp = \q -> do
            loc <- location
            let e_ast = parseQuery (show loc) q
            case e_ast of
                Right ast -> makeArityQuery q ast
                    (maxParamQuery ast)
                    (countColumnsReturned ast)
                Left err -> error err
    , quotePat = \_ -> error "qq aritySql cannot be used in pattern context"
    , quoteType = \_ -> error "qq aritySql cannot be used in type context"
    , quoteDec = \_ -> error "qq aritySql cannot be used in declaration context"
    }

countColumnsReturned :: Syntax.Query -> Int
countColumnsReturned (QS (Select {columns})) = length columns
countColumnsReturned _ = 0

-- TODO update because Expr is allowed more places
maxParamQuery :: Query -> Word
maxParamQuery (QS (Select {conditions})) = case conditions of
                          Nothing -> 0
                          Just c -> maxParamCondition c
maxParamQuery _ = 0

maxParamCondition :: Condition -> Word
maxParamCondition condition = case condition of
    Compare _ _ e -> maxParamExpr e
    Or l r -> max (maxParamCondition l) (maxParamCondition r)
    And l r -> max (maxParamCondition l) (maxParamCondition r)
    Not c -> maxParamCondition c

maxParamExpr :: Expr -> Word
maxParamExpr expr = case expr of
    Param i -> i
    BinOp _ l r -> max (maxParamExpr l) (maxParamExpr r)
    Unary _ e -> maxParamExpr e
    Lit _ -> 0
    Var _ -> 0
