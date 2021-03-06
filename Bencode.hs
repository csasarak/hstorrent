{-|
  Module      : Bencode 
  Description : Implementation of Bencoding for bittorrent as described at http://www.bittorrent.org/beps/bep_0003.html
  Copyright   : (c) Christopher Sasarak, 2014
  License     : GPL-3
  Maintainer  : cms5347@rit.edu
  Stability   : experimental
  
 -}

module Bencode where

import Text.Parsec.Char
import Text.Parsec.Prim
import Text.ParserCombinators.Parsec.Prim
import Text.Parsec.Combinator
import qualified Text.Parsec.Error as PE
import Data.Char
import qualified Data.Map as M
import qualified Control.Monad as Mon
import qualified Control.Applicative as CA

-- | A map from Bencode data to Bencode data
type BMapT = M.Map Bencode Bencode

data Bencode =  -- |Constructor for a Bencoded Integer
                Bint Integer
                -- |Constructor for a Bencoded String
              | Bstr String
                -- |Constructor for a list of Bencoded items
              | Blist [Bencode]
                -- |Constructor for a Bencoded Map (dictionary)
              | Bmap BMapT
              deriving (Eq, Ord)

instance Show Bencode where
    show (Bint i) = "i" ++ show i ++ "e"
    show (Bstr s) = (show . length) s ++ ":" ++ s
    show (Blist bs) = 'l':concatMap show bs ++ "e"
    show (Bmap bm) = M.foldlWithKey (\a k b -> a ++ show k ++ show b) "d" bm  ++ "e"

-- |Parser for a Bencoded Integer
bInt :: Parser Bencode
bInt = Bint CA.<$> (char 'i' CA.*> validNum CA.<* char 'e' )
       -- This parser parses valid integers in Bencodings 
       where validNum = do neg <- option ' ' (char '-')
                           d <- digit
                           case digitToInt d of
                                -- Only time the first digit == 0 is "i0e"
                                0 -> if neg == ' ' then 
                                        -- "i0e" allowed but NOT "i-0e" or zero padded integer
                                        lookAhead (char 'e') >> return 0 
                                     else
                                        parserFail "Can't have a negative zero"
                                _ -> many digit >>= \xs -> return $ read (neg:d:xs)
       
-- |Parser for a Bencoded String
bString :: Parser Bencode
bString = do ss <- many1 digit
             char ':'
             let size = read ss
             Mon.liftM Bstr $ count size anyChar
             
-- |Parser for a Bencoded list
bList :: Parser Bencode
bList = do char 'l' 
           ls <- many (bInt <|> bString <|> bList <|> bMap)
           char 'e'
           return $ Blist ls
 
-- |Parser for a Bencoded dictionary
bMap :: Parser Bencode
bMap = do char 'd'
          entries <- many dictEntry
          char 'e'
          return $ Bmap $ M.fromList entries

-- |Parser for a key-value pair
dictEntry :: Parser (Bencode, Bencode)
dictEntry = do key <- bString
               value <- bString <|> bList <|> bInt <|> bMap
               return (key, value)

-- |Read a Bencoded dictionary from filename
readBencodedFile :: String -> IO (Either PE.ParseError Bencode)
readBencodedFile = parseFromFile bMap
