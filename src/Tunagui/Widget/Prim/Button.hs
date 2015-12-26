module Tunagui.Widget.Prim.Button
  (
    Button (..), ButtonConfig (..)
  , newButton
  ) where

import           Control.Monad.IO.Class                      (MonadIO, liftIO)
import           FRP.Sodium
import           Linear.V2
import           Linear.V4

import qualified Tunagui.General.Data              as D
import qualified Tunagui.General.Types             as T
import           Tunagui.Internal.Operation.Render as R
import           Tunagui.Widget.Features           (Clickable,
                                                   Renderable,
                                                   onClick, render,
                                                   locate)
import qualified Tunagui.Widget.Component          as CMP

-- TODO: Hide 'newButton' from user

data Button = Button
  { btnPos     :: Behavior (T.Point Int)
  , btnSize    :: Behavior (T.Size Int)
  -- Setter of attributes
  , setPos     :: T.Point Int -> Reactive ()
  -- Features
  , btnClkArea :: CMP.ClickableArea
  }

data ButtonConfig = ButtonConfig
  { btnWidth  :: Int
  , btnHeight :: Int
  }

instance Show Button where
  show _ = "< Button >"

instance Clickable Button where
  onClick = CMP.clickEvent . btnClkArea

instance Renderable Button where
  render = renderB
  locate = locateB

newButton :: ButtonConfig -> D.WinEvents -> IO Button
newButton cfg es =
  sync $ do
    (behPos, pushPos) <- newBehavior $ T.P (V2 0 0)
    (behSize, _)      <- newBehavior iniSize
    let behShape = T.Rect <$> behSize
    clk <- CMP.mkClickableArea behPos behShape (D.wePML es) (D.weRML es)
    return Button
      { btnPos = behPos
      , btnSize = behSize
      , setPos = pushPos
      , btnClkArea = clk
      }
  where
    w = btnWidth cfg
    h = btnHeight cfg
    iniSize = T.S (V2 w h)

locateB :: Button -> T.Point Int -> Reactive (T.Range Int)
locateB btn p = do
  setPos btn p
  pos <- sample (btnPos btn)
  size <- sample (btnSize btn)
  return $ T.R pos (pos `T.plusPS` size)

renderB :: MonadIO m => Button -> R.RenderP m ()
renderB btn = do
  (p,s) <- liftIO . sync $ (,) <$> sample (btnPos btn) <*> sample (btnSize btn)
  R.setColor $ V4 255 255 255 255
  R.fillRect p s
  R.setColor $ V4 137 140 149 255
  R.drawRect p s
