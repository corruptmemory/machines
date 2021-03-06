{-# LANGUAGE GADTs #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Data.Machine.Unread
-- Copyright   :  (C) 2012 Edward Kmett
-- License     :  BSD-style (see the file LICENSE)
--
-- Maintainer  :  Edward Kmett <ekmett@gmail.com>
-- Stability   :  provisional
-- Portability :  GADTs
--
----------------------------------------------------------------------------
module Data.Machine.Unread
  ( Unread(..)
  , peek
  , unread
  , unreading
  ) where

import Data.Machine.Await
import Data.Machine.Plan
import Data.Machine.Process
import Data.Machine.Type

-- | This is a simple process type that knows how to push back input.
data Unread o a where
  Unread :: a -> o -> Unread o a
  Read   :: (o -> a) -> Unread o a

instance Functor (Unread o) where
  fmap f (Unread r a) = Unread (f r) a
  fmap f (Read k) = Read (f . k)

instance Await a (Unread a) where
  await = Read id

-- | Peek at the next value in the input stream without consuming it
peek :: Plan b (Unread a) a
peek = do
  a <- await
  unread a
  return a

-- | Push back into the input stream
unread :: a -> Plan b (Unread a) ()
unread a = request $ Unread () a

-- | Construct a process from a plan that requires unreading
unreading :: Plan b (Unread o) a -> Process o b
unreading = go . construct where
  go Stop        = Stop
  go (Yield o k) = Yield o (go k)
  go (Await k (Read m) e)     = Await (go . k) m (go e)
  go (Await k (Unread a o) _) = supply [o] (go (k a))
