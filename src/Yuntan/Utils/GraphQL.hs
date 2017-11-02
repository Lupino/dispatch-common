{-# LANGUAGE OverloadedStrings #-}

module Yuntan.Utils.GraphQL
  (
    getValue
  , getIntValue
  , getFloatValue
  , getTextValue
  , getEnumValue
  , getBoolValue
  , getObjectValue
  , getListValue
  , value
  , value'
  ) where

import           Control.Applicative   (Alternative (..))

import qualified Data.Aeson            as A (Value (..))
import           Data.GraphQL.AST      (Name)
import           Data.GraphQL.AST.Core (ObjectField)
import           Data.GraphQL.Schema   (Argument (..), Resolver, Value (..),
                                        array, object, scalar)
import qualified Data.HashMap.Strict   as HM (toList)
import           Data.Text             (Text)
import qualified Data.Vector           as V (Vector, head, null, toList)

import           Haxl.Core             (GenHaxl, throw)
import           Haxl.Prelude          (NotFound (..), catchAny)


instance Alternative (GenHaxl u) where
  a <|> b = catchAny a b
  empty = throw $ NotFound "mzero"

getValue :: Name -> [Argument] -> Maybe Value
getValue _ [] = Nothing
getValue k (Argument n v:xs) | k == n = Just v
                             | otherwise = getValue k xs

getIntValue :: Num a => Name -> [Argument] -> Maybe a
getIntValue n argv = case getValue n argv of
                       (Just (ValueInt v)) -> Just $ fromIntegral v
                       _                   -> Nothing

getFloatValue :: Name -> [Argument] -> Maybe Double
getFloatValue n argv = case getValue n argv of
                         (Just (ValueFloat v)) -> Just v
                         _                     -> Nothing

getBoolValue :: Name -> [Argument] -> Maybe Bool
getBoolValue n argv = case getValue n argv of
                        (Just (ValueBoolean v)) -> Just v
                        _                       -> Nothing

getTextValue :: Name -> [Argument] -> Maybe Text
getTextValue n argv = case getValue n argv of
                        (Just (ValueString v)) -> Just v
                        _                      -> Nothing

getEnumValue :: Name -> [Argument] -> Maybe Name
getEnumValue n argv = case getValue n argv of
                        (Just (ValueEnum v)) -> Just v
                        _                    -> Nothing

getObjectValue :: Name -> [Argument] -> Maybe [ObjectField]
getObjectValue n argv = case getValue n argv of
                          (Just (ValueObject v)) -> Just v
                          _                      -> Nothing

getListValue :: Name -> [Argument] -> Maybe [Value]
getListValue n argv = case getValue n argv of
                        (Just (ValueList v)) -> Just v
                        _                    -> Nothing

value :: Alternative f => Name -> A.Value -> Resolver f
value k vv@(A.Object v) = object k . (scalar "_all" vv :) . listToResolver $ HM.toList v
value k (A.Array v)     = if isO v then array k (map value' $ V.toList v)
                                else scalar k v
value k v               = scalar k v

isOv :: A.Value -> Bool
isOv (A.Object _) = True
isOv _            = False

isO :: V.Vector A.Value -> Bool
isO v | V.null v  = False
      | otherwise = isOv $ V.head v

value' :: Alternative f => A.Value -> [Resolver f]
value' vv@(A.Object v) = (scalar "_all" vv :) . listToResolver $ HM.toList v
value' _               = []

listToResolver :: Alternative f => [(Text, A.Value)] -> [Resolver f]
listToResolver []          = []
listToResolver ((k, v):xs) = value k v : listToResolver xs
