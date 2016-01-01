module Tunagui.Widget.Prim.Label
  (
    Label (..)
  , Config (..), defaultConfig
  , newLabelT, newLabelB
  ) where

import Control.Monad (void)
import Control.Monad.IO.Class (liftIO)
import FRP.Sodium
import qualified Data.Text as T
import Linear.V2

import qualified Tunagui.General.Data as D
import Tunagui.General.Types (Point(..), Size(..), Range(..), plusPS)
import Tunagui.General.Base (TunaguiT)
import Tunagui.Internal.Render as R
import Tunagui.Internal.Render.SDL (runRender)
import Tunagui.Widget.Component.Features (Renderable, render, locate, update)
import Tunagui.Widget.Component.Util (up')
import Tunagui.General.Layout (DimSize (..), mkSizeBehav)

data Label = Label
  { pos :: Behavior (Point Int)
  , size :: Behavior (Size Int)
  , text :: Behavior T.Text
  --
  , setPos :: Point Int -> Reactive ()
  , update_ :: Event String
  }

data Config = Config
  { width :: DimSize Int
  , height :: DimSize Int
  , minWidth :: Maybe Int
  , maxWidth :: Maybe Int
  , minHeight :: Maybe Int
  , maxHeight :: Maybe Int
  } deriving Show

defaultConfig :: Config
defaultConfig = Config
  { width = RelContent
  , height = RelContent
  , minWidth = Nothing
  , maxWidth = Nothing
  , minHeight = Nothing
  , maxHeight = Nothing
  }

instance Show Label where
  show _ = "< LABEL >"

instance Renderable Label where
  render = render_
  locate = locate_
  update = update_

newLabelT :: Config -> D.Window -> T.Text -> TunaguiT Label
newLabelT c w t =
  newLabelB c w =<< toBeh t
  where
    toBeh = fmap fst . liftIO . sync . newBehavior

newLabelB :: Config -> D.Window -> Behavior T.Text -> TunaguiT Label
newLabelB cnf win behText = do
  text <- liftIO . sync $ sample behText
  (S (V2 w h)) <- runRender (D.wRenderer win) (R.textSize text)
  liftIO . sync $ do
    (behCW, _) <- newBehavior w
    (behCH, _) <- newBehavior h
    behW <- mkSizeBehav (width cnf) (minWidth cnf) (maxWidth cnf) behCW
    behH <- mkSizeBehav (height cnf) (minHeight cnf) (maxHeight cnf) behCH
    let behSize = S <$> (V2 <$> behW <*> behH)
    (behPos, pushPos) <- newBehavior $ P (V2 0 0)
    -- Make update event
    let eUpdate = up' "Label.behText" behText
    return Label
      { pos = behPos
      , size = behSize
      , text = behText
      , setPos = pushPos
      , update_ = eUpdate
      }

locate_ :: Label -> Point Int -> Reactive (Range Int)
locate_ label p = do
  setPos label p
  pos <- sample $ pos label
  size <- sample $ size label
  return $ R pos (pos `plusPS` size)

render_ :: Label -> R.RenderP TunaguiT ()
render_ label = do
  (p,t) <- liftIO . sync $
              (,) <$> sample (pos label)
                  <*> sample (text label)
  R.renderText p t