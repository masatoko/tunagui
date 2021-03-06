module Tunagui.Widget.Prim.Button
  (
    Button (..), Config (..)
  , defaultConfig
  , mkButton
  ) where

import           Control.Monad.IO.Class   (liftIO)
import           FRP.Sodium
import           Linear.V2
import qualified Data.Text                as T
import           Data.List                (foldl1')

import qualified Graphics.UI.SDL.TTF as TTF

import qualified Tunagui.General.Data     as D
import           Tunagui.General.Data     (DimSize (..))
import           Tunagui.General.Types    (Point(..), Size(..), Shape(..), plusPP)
import           Tunagui.General.Base     (TunaguiT)
import           Tunagui.Internal.Render  as R
import           Tunagui.Internal.Render (RenderT)
import           Tunagui.Widget.Component.Features
import qualified Tunagui.Widget.Component.Part as PRT
import           Tunagui.Widget.Component.Util (up, mkSizeBehav)
import           Tunagui.Widget.Component.Color as COL
import           Tunagui.Widget.Component.Conf (DimConf (..))

data Button = Button
  { modifyText :: (T.Text -> T.Text) -> Reactive ()
  --
  , color :: Behavior COL.ShapeColor
  -- Features
  , btnClkArea :: PRT.ClickableArea
  , render_ :: RenderT ()
  , locate_ :: Point Int -> IO ()
  , sizeof_ :: IO (Size Int)
  , updated_ :: Event ()
  , resized_ :: Event (Size Int)
  , free_ :: IO ()
  }

data Config = Config
  { width  :: DimSize Int
  , widthConf :: DimConf Int
  , height :: DimSize Int
  , heightConf :: DimConf Int
  --
  , bcText :: Maybe T.Text
  } deriving Show

defaultConfig :: Config
defaultConfig = Config
  { width = RelContent
  , widthConf = DimConf Nothing Nothing 4 4 2 2
  , height = RelContent
  , heightConf = DimConf Nothing Nothing 2 2 2 2
  --
  , bcText = Nothing
  }

instance Show Button where
  show _ = "< BUTTON >"

instance Clickable Button where
  clickEvent = PRT.clickEvent . btnClkArea

instance Renderable Button where
  render = render_
  locate = locate_
  sizeof = sizeof_
  updated = updated_
  resized = resized_
  free = free_

mkButton :: Config -> D.Window -> TunaguiT Button
mkButton conf win =
  liftIO $ do
    font <- TTF.openFont "data/sample.ttf" 16
    sync $ do
      -- Text
      tc <- PRT.mkTextContent win font (bcText conf)
      -- Position
      (behAbsPos0, pushAbsPos0) <- newBehavior $ P (V2 100000 100000)
      -- Size
      (behBorderRelPos, behTextRelPos, behBorderSize, behRangeSize) <- mkSizeBehav' conf tc
      -- Make parts
      let behBorderAbsPos = plusPP <$> behAbsPos0 <*> behBorderRelPos
      clk <- PRT.mkClickableArea behBorderAbsPos (Rect <$> behBorderSize) (D.wePML events) (D.weRML events) (D.weMMPos events)
      -- Hover
      behShapeColor <- hold COL.planeShapeColor $ toShapeColor <$> PRT.crossBoundary clk
      -- Update event
      let updated' = foldl1' mappend
            [ up behBorderSize
            , up behRangeSize
            , up behShapeColor
            ]

      let render' = do
            (bp, bs, tp, c, t) <- liftIO . sync $ do
              bp <- sample behBorderRelPos
              bs <- sample behBorderSize
              tp <- sample behTextRelPos
              c <- sample behShapeColor
              t <- sample $ PRT.tcText tc
              return (bp, bs, tp, c, t)
            R.setColor $ COL.fill c
            R.fillRect bp bs
            R.setColor $ COL.border c
            R.drawRect bp bs
            -- Text
            R.renderText font tp t

      let free' = do
            putStrLn "free Button"
            TTF.closeFont font
      return Button
        { modifyText = PRT.modifyText tc
        --
        , color = behShapeColor
        -- Features
        , btnClkArea = clk
        , render_ = render'
        , locate_ = sync . pushAbsPos0
        , sizeof_ = sync $ sample behRangeSize
        , updated_ = updated'
        , resized_ = updates behRangeSize
        , free_ = free'
        }
  where
    events = D.wEvents win
    toShapeColor :: Bool -> COL.ShapeColor
    toShapeColor True  = COL.hoverShapeColor
    toShapeColor False = COL.planeShapeColor

    mkSizeBehav' c tc =
      mkSizeBehav (width c) (widthConf c) (PRT.tcWidth tc)
                  (height c) (heightConf c) (PRT.tcHeight tc)
