{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- NOTE: re-exported from Test.Hspec.Core.Spec
module Test.Hspec.Core.Spec.Monad (
  Spec
, SpecWith
, SpecM (..)
, runSpecM
, fromSpecList
, runIO

, mapSpecForest
, mapSpecItem
, mapSpecItem_
, modifyParams

, modifyConfig
) where

import           Prelude ()
import           Test.Hspec.Core.Compat

import           Control.Arrow
import           Control.Monad.Trans.Writer
import           Control.Monad.IO.Class (liftIO)

import           Test.Hspec.Core.Example
import           Test.Hspec.Core.Tree

import           Test.Hspec.Core.Config.Definition (Config)

type Spec = SpecWith ()

type SpecWith a = SpecM a ()

-- |
-- @since 2.10.0
modifyConfig :: (Config -> Config) -> SpecWith a
modifyConfig f = SpecM $ tell (Endo f, mempty)

-- | A writer monad for `SpecTree` forests
newtype SpecM a r = SpecM (WriterT (Endo Config, [SpecTree a]) IO r)
  deriving (Functor, Applicative, Monad)

-- | Convert a `Spec` to a forest of `SpecTree`s.
runSpecM :: SpecWith a -> IO (Endo Config, [SpecTree a])
runSpecM (SpecM specs) = execWriterT specs

-- | Create a `Spec` from a forest of `SpecTree`s.
fromSpecForest :: (Endo Config, [SpecTree a]) -> SpecWith a
fromSpecForest = SpecM . tell

-- | Create a `Spec` from a forest of `SpecTree`s.
fromSpecList :: [SpecTree a] -> SpecWith a
fromSpecList = fromSpecForest . (,) mempty

-- | Run an IO action while constructing the spec tree.
--
-- `SpecM` is a monad to construct a spec tree, without executing any spec
-- items.  @runIO@ allows you to run IO actions during this construction phase.
-- The IO action is always run when the spec tree is constructed (e.g. even
-- when @--dry-run@ is specified).
-- If you do not need the result of the IO action to construct the spec tree,
-- `Test.Hspec.Core.Hooks.beforeAll` may be more suitable for your use case.
runIO :: IO r -> SpecM a r
runIO = SpecM . liftIO

mapSpecForest :: ([SpecTree a] -> [SpecTree b]) -> SpecM a r -> SpecM b r
mapSpecForest f (SpecM specs) = SpecM (mapWriterT (fmap (fmap (second f))) specs)

mapSpecItem :: (ActionWith a -> ActionWith b) -> (Item a -> Item b) -> SpecWith a -> SpecWith b
mapSpecItem g f = mapSpecForest (bimapForest g f)

mapSpecItem_ :: (Item a -> Item a) -> SpecWith a -> SpecWith a
mapSpecItem_ = mapSpecItem id

modifyParams :: (Params -> Params) -> SpecWith a -> SpecWith a
modifyParams f = mapSpecItem_ $ \item -> item {itemExample = \p -> (itemExample item) (f p)}
