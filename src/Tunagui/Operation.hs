{-# LANGUAGE GADTs #-}

-- Users can use these operations.

module Tunagui.Operation
  (
    TunaguiP, interpret
  --
  , testOperation
  , mkButton
  ) where

import           Control.Monad.Operational
import           Control.Monad.Reader                  (asks)
import           FRP.Sodium
import           Linear.V2                             (V2 (..))
import           Linear.V4                             (V4 (..))

import qualified Tunagui.General.Data                  as D
import qualified Tunagui.General.Types                 as T
import           Tunagui.Internal.Base
import qualified Tunagui.Internal.Operation.Render.SDL as R

import           Tunagui.Widgets.Features
import qualified Tunagui.Widgets.Prim.Button           as Button

-- *****************************************************************************
data TunaguiI a where
  TestOperation :: TunaguiI ()
  -- make widgets
  MkButton      :: Button.ButtonConfig -> TunaguiI Button.Button

type TunaguiP m a = ProgramT TunaguiI m a

interpret :: TunaguiP Base a -> Base a
interpret is = eval =<< viewT is

-- *****************************************************************************
testOperation = singleton TestOperation
mkButton      = singleton . MkButton

-- *****************************************************************************
eval :: ProgramViewT TunaguiI Base a -> Base a
eval (Return a) = return a

-- test mouse button click
eval (TestOperation :>>= is) = do
  e <- asks (D.ePML . D.cntEvents)
  liftIO . sync $ listen e print
  --
  r <- asks (D.twRenderer . D.cntTWindow)
  liftIO . R.runRender r $ do
    R.setColor (V4 255 0 0 255)
    R.clear
    R.setColor (V4 255 255 255 255)
    R.drawRect (T.P (V2 100 100)) (T.S (V2 100 100))
    R.flush
  interpret (is ())

-- make widgets ================================================================
eval (MkButton cfg :>>= is) = interpret . is =<< Button.newButton cfg
