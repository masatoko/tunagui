module Tunagui.General.Event
  ( listenAllEvents
  ) where

import           Control.Applicative
import           Control.Concurrent    (forkIO)
import           Control.Monad         (unless, when)
import           FRP.Sodium
import qualified Linear.Affine         as A

import qualified SDL

import           Tunagui.General.Data  (FrameEvents (..))
import qualified Tunagui.General.Types as T

type EventPusher = SDL.Event -> Reactive ()

listenAllEvents :: IO FrameEvents
listenAllEvents = do
  (eQuit', pQuit) <- quitEvent
  (ePML',  pPML)  <- mouseEvent SDL.Pressed  SDL.ButtonLeft
  (eRML',  pRML)  <- mouseEvent SDL.Released SDL.ButtonLeft
  --
  let ps = [pQuit, pPML, pRML]
  forkIO $ eventLoop ps
  return FrameEvents
    { eQuit = eQuit'
    , ePML = ePML'
    , eRML = eRML'
    }
  where
    eventLoop :: [EventPusher] -> IO ()
    eventLoop ps = go
      where
        go = do
          es <- SDL.pollEvents
          mapM_ sync [f e | f <- ps, e <- es]
          unless (any isQuit es) go
        --
        isQuit e = SDL.eventPayload e == SDL.QuitEvent

type EventPair a = (Event a, EventPusher)
type EventHelper a = (a -> Reactive ()) -> SDL.Event -> Reactive ()

quitEvent :: IO (EventPair ())
quitEvent = fmap work <$> sync newEvent
  where
    work push e = when (SDL.eventPayload e == SDL.QuitEvent) $ push ()

mouseEvent :: SDL.InputMotion -> SDL.MouseButton -> IO (EventPair T.IPoint)
mouseEvent motion button = fmap work <$> sync newEvent
  where
    work push e =
      case SDL.eventPayload e of
        SDL.MouseButtonEvent dat -> do
          let isM = SDL.mouseButtonEventMotion dat == motion
              isB = SDL.mouseButtonEventButton dat == button
              (A.P p) = SDL.mouseButtonEventPos dat
          when (isM && isB) $ push $ fromIntegral <$> T.P p