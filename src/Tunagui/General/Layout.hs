{-# LANGUAGE ExistentialQuantification #-}

module Tunagui.General.Layout
  (
    WidgetTree (..)
  , Direction (..)
  , locateWT
  , renderWT
  , updateEventWT
  , DimSize (..)
  --
  , mkSizeBehav
  ) where

import           Control.Monad           (foldM, void)
import           Control.Monad.IO.Class  (MonadIO)
import           Data.List               (foldl', foldl1')
import           FRP.Sodium
import           Linear.V2

import qualified Tunagui.General.Types   as T
import           Tunagui.General.Base    (TunaguiT)
import           Tunagui.Internal.Render (RenderP)
import           Tunagui.Widget.Component.Features (Renderable, locate, render, update)

data WidgetTree =
  forall a. (Show a, Renderable a)
  => Widget T.WidgetId a | Container Direction [WidgetTree]

data Direction
  = DirH -- Horizontal
  | DirV -- Vertical
  deriving Show

instance Show WidgetTree where
  show (Widget i a) = "Widget#" ++ show i ++ " " ++ show a
  show (Container dir ws) = "Container " ++ show dir ++ " " ++ show ws

-- |
-- Fix the location of WidgetTree
locateWT :: WidgetTree -> IO ()
locateWT widgetTree = void . sync $ go widgetTree (T.P (V2 0 0))
  where
    go :: WidgetTree -> T.Point Int -> Reactive (T.Range Int)
    go (Widget _ a)         p0 = locate a p0
    go (Container dir ws) p0 = do
      ranges <- foldM locate' [T.R p0 p0] ws
      return $ T.R (foldl' leftTop p0 ranges) (foldl' rightBottom p0 ranges)
      where
        locate' :: [T.Range Int] -> WidgetTree -> Reactive [T.Range Int]
        locate' []       _    = undefined
        locate' rs@(r:_) tree = (:rs) <$> work tree (nextFrom r)
          where
            work (Widget _ a)        = locate a
            work cnt@(Container _ _) = go cnt

        leftTop :: Ord a => T.Point a -> T.Range a -> T.Point a
        leftTop point range =
          let (T.P (V2 x y)) = point
              (T.R (T.P (V2 x' y')) _) = range
          in T.P (V2 (min x x') (min y y'))

        rightBottom :: Ord a => T.Point a -> T.Range a -> T.Point a
        rightBottom point range =
          let (T.P (V2 x y)) = point
              (T.R _ (T.P (V2 x' y'))) = range
          in T.P (V2 (max x x') (max y y'))

        nextFrom (T.R (T.P (V2 x0 y0)) (T.P (V2 x1 y1))) =
          case dir of
            DirH -> T.P (V2 x1 y0)
            DirV -> T.P (V2 x0 y1)

-- |
-- Render all widgets in WidgetTree.
renderWT :: WidgetTree -> RenderP TunaguiT ()
renderWT (Widget _ a)       = render a
renderWT (Container _ ws) = mapM_ renderWT ws

updateEventWT :: WidgetTree -> Event String
updateEventWT (Widget _ a)       = update a
updateEventWT (Container _ ws) = foldl1' (mergeWith (\a b -> a ++ "|" ++ b)) $ map updateEventWT ws

-- *****************************************************************************

mkSizeBehav :: Ord a => DimSize a -> Maybe a -> Maybe a -> Behavior a -> Reactive (Behavior a)
mkSizeBehav dimA minA maxA behContent = do
  behA <- case dimA of
    Absolute a -> fst <$> newBehavior a
    RelContent -> return behContent
  return $ conv min minA . conv max maxA <$> behA
  where
  conv minmax (Just x) = minmax x
  conv _      Nothing  = id

-- | One dimensional size
data DimSize a
  = Absolute a
  | RelContent
  deriving (Eq, Show)