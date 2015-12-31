{-# LANGUAGE OverloadedStrings #-}

module Main where

import           Control.Concurrent     (threadDelay, forkIO)
import           Control.Monad          (forever, void)
import           Control.Monad.IO.Class (liftIO)
import           FRP.Sodium
import           Linear.V2
import qualified Data.Text              as T

import qualified Tunagui                as GUI
import           Tunagui                (runTuna, WidgetTree (..), Direction (..)
                                        ,withWindow, WinConfig (..))
import           Tunagui.Widget         (onClick)
import qualified Tunagui.Widget.Button  as Button
import qualified Tunagui.Widget.Label   as Label
import           Tunagui.Operation

main :: IO ()
main = testLabel

testLabel :: IO ()
testLabel =
  GUI.withTunagui $ \tuna ->
    withWindow (WinConfig "main" True (V2 300 300)) tuna $ \win -> do
      (beh, push) <- liftIO . sync $ newBehavior (0 :: Integer)
      runTuna tuna $ runWin win $ do
        (btn,wBtn) <- Button.mkButton (Button.defaultConfig {Button.bcText = Just " plus "})
        (_,wLbl) <- Label.mkLabelB Label.defaultConfig (T.pack . show <$> beh)
        testOverwriteTreeOP (Container DirV [wLbl,wBtn])
        testRenderTree
        liftIO . sync $ listen (onClick btn) $ \_ ->
          void . forkIO . sync $ do
            i <- sample beh
            push $ i + 1

      liftIO . forever $ do
        putStrLn "."
        threadDelay 1000000

test :: IO ()
test =
  GUI.withTunagui $ \tuna ->
    -- 1st window
    withWindow (WinConfig "main" True (V2 600 400)) tuna $ \win1 -> do
      (beh,push) <- liftIO (sync (newBehavior (0::Integer)))
      _ <- runTuna tuna $ runWin win1 $ do
        (btn1, w1B) <- Button.mkButton (Button.defaultConfig {Button.bcText = Just "button1"})
        (_, w1L) <- Label.mkLabelT Label.defaultConfig "Label"
        (_, w1L') <- Label.mkLabelB Label.defaultConfig (T.pack . show <$> beh)
        testOverwriteTreeOP (Container DirV [w1B,w1L,w1L'])
        testRenderTree
        liftIO . sync $ listen (onClick btn1) $ \p -> putStrLn $ "click (1): " ++ show p
      -- 2nd window
      withWindow (WinConfig "sub" False (V2 200 200)) tuna $ \win2 -> do
        _ <- runTuna tuna $ runWin win2 $ do
          (btn2, w2) <- Button.mkButton (Button.defaultConfig {Button.bcText = Just "button2"})
          testOverwriteTreeOP (Container DirV [w2])
          testRenderTree
          liftIO . sync $ listen (onClick btn2) $ \p -> putStrLn $ "click (2): " ++ show p
        --
        let loop = do
              putStrLn "."
              threadDelay 1000000
              -- q <- sync $ sample quit
              -- unless q loop

              -- TEST count
              sync $ do
                i <- sample beh
                push $ i + 1

              loop
        liftIO loop
