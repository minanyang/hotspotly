<div align="center">

<img src="docs/icon.png" width="128" alt="Hotspotly 圖示">

# Hotspotly

讓 Mac 穩穩連在手機熱點和 Wi-Fi 上。

[![Release](https://img.shields.io/github/v/release/minanyang/hotspotly)](https://github.com/minanyang/hotspotly/releases/latest)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

[English](README.md) · **繁體中文** · [下載](https://github.com/minanyang/hotspotly/releases/latest/download/Hotspotly.zip)

</div>

<p align="center">
  <img src="docs/screenshots/zh-TW/menu-dark.png" width="306" alt="Hotspotly 選單：連線和保護兩個燈、訊號、頻道、Wi-Fi 標準和已用流量">
</p>

Hotspotly 是一個選單列 app，給常常連手機熱點的 Mac 使用。它讓連線不容易斷、顯示連線品質，也幫你整理 Mac 記住的網路。

- **防止熱點斷線。** 連在熱點上時關掉 AWDL（AirDrop 用的無線連線，會不斷把 Wi-Fi 晶片切到別的頻道），離開熱點後再打開。
- **讓熱點保持開啟。** 定期 ping 手機，熱點不會因為閒置而關閉。
- **釘選網路。** macOS 自己跑到其他記住的網路時，把 Mac 拉回來。
- **顯示連線狀態。** 到路由器的延遲和掉包率、訊號、頻道、Wi-Fi 標準；連著熱點時，還有 Mac 用了多少流量。
- **管理記住的網路。** 列出 Mac 記住的所有網路，包括安全性和連線品質，可以一次忘記好幾個。
- **自動更新。** 有 Developer ID 簽章、經過 Apple 公證，在 app 裡就能更新。

iPhone 熱點會自動辨識；Android 手機和行動網卡可以手動標記。選單會跟著系統語言顯示繁體中文或英文。

## 安裝

需要 macOS 13（Ventura）或更新版本。

1. 下載 [Hotspotly.zip](https://github.com/minanyang/hotspotly/releases/latest/download/Hotspotly.zip)，解壓縮後把 **Hotspotly** 拖進「應用程式」並打開。它有 Developer ID 簽章，也經過 Apple 公證。
2. 出現詢問時按「**打開系統設定**」，在「**登入項目與延伸功能 → 允許在背景執行**」打開 **Hotspotly**，允許它的輔助程式（原因見[權限](#權限)）。
3. 詢問位置權限時按「允許」，選單才能顯示網路名稱。
4. 在選單的「**設定… → 一般**」打開「**登入時開啟**」。

熟悉終端機的話，也可以用一行指令安裝：

```sh
curl -fsSL https://raw.githubusercontent.com/minanyang/hotspotly/main/install.sh | bash
```

### 從原始碼編譯

需要 Xcode Command Line Tools。

```sh
git clone https://github.com/minanyang/hotspotly
cd hotspotly
make install          # 編譯 Hotspotly.app 並放進「應用程式」；第一次編譯會下載 Sparkle
open /Applications/Hotspotly.app
```

## 使用方式

### 選單

最上面的開關可以關閉或重新開啟 Hotspotly。下面有兩個燈，就像圖示裡路由器上的兩個燈：

- **目前的網路**：過去一分鐘到路由器的延遲和掉包率，下面再列出訊號、頻道和 Wi-Fi 標準；連著熱點時，也會顯示連上後 Mac 用了多少流量。橘燈表示有掉包或延遲偏高；紅燈表示路由器沒有回應。
- **保護**：AWDL 已關閉、在釘選的網路上。橘燈表示正在允許 AirDrop，或 Mac 離開了釘選的網路。

連著熱點時會出現「**允許 AirDrop 10 分鐘**」，圖示的路由器也會變成實心。「**設定…**」（⌘,）會打開下面介紹的設定視窗。

### 在哪裡關閉 AWDL

「**設定… → 一般**」的「**關閉 AWDL**」可以選擇在哪裡關掉 AWDL：在手機熱點上（預設）、在所有網路上，或永不。

### 釘選網路

在「**釘選網路**」選一個網路，Mac 跑到別的網路時，Hotspotly 會把它拉回來，試幾次不成功就會停止。第一次需要 Wi-Fi 密碼：直接輸入，或按「**使用這台 Mac 儲存的密碼…**」並輸入 Mac 的登入密碼，讓 Hotspotly 讀取 macOS 存的那份。密碼會存在你的登入鑰匙圈，之後自動連回不會再詢問。iPhone 熱點停止廣播後，Hotspotly 叫不醒它，內建的 Wi-Fi 選單可以。

### 記住的網路

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/zh-TW/networks-dark.png">
    <img src="docs/screenshots/zh-TW/networks-light.png" width="720" alt="設定的網路分頁：記住的網路，包括安全性、上次連線和連線品質">
  </picture>
</p>

「**設定… → 網路**」會列出 Mac 記住的所有網路，包括安全性（開放和 WEP 網路以橘色標示）、上次連線時間和連線品質。iPhone 熱點會自動偵測；選取 Android 手機或行動網卡，按「**標記為手機熱點**」就會把它當成熱點。可以選取多個網路，按「**忘記…**」就能一起移除。macOS 自己記錄的連線日期只有 root 加上「完整磁碟取用權限」才讀得到，所以 Hotspotly 從安裝後開始自己記錄。

### 成效分析

「**設定… → 成效分析**」會告訴你 Hotspotly 在你的網路上有沒有幫助。它比較 AWDL 關閉和開啟時（允許 AirDrop 期間，或 Hotspotly 不處理的網路上）的延遲、掉包和斷線，列出最近的斷線和系統 log 裡記錄的原因（手機或路由器中斷了連線、訊號消失、macOS 換到其他網路、Mac 進入睡眠），並統計 Hotspotly 做了什麼。量測資料只會留在你的 Mac 上。

### 更新

Hotspotly 每天會檢查一次有沒有新版本，有的話會出現在選單裡；也可以按「**檢查更新…**」馬上檢查。更新檔來自這個 repo 的 release，經過簽名驗證，按一下就能安裝。在「**設定… → 關於**」可以開關自動檢查和自動安裝。

### 其他

在「**設定… → 一般**」打開「**隱藏選單列圖示**」，Hotspotly 會在沒有圖示的情況下繼續執行，要看設定時從「應用程式」再打開它一次。結束 Hotspotly 後 AWDL 會重新打開。Log 檔在 `~/Library/Logs/hotspotly.log`。

## 什麼是 AWDL？

AWDL（Apple Wireless Direct Link）讓 Apple 裝置直接用 Wi-Fi 互相連線，AirDrop、接力、通用控制和隨航都靠它。它和你的 Wi-Fi 連線共用 Mac 唯一的一組無線電，每秒會好幾次把無線電切到別的頻道去找附近的裝置。家裡的路由器還能應付；手機熱點則常常延遲飆高，甚至斷線。

關掉 AWDL 就能解決，但那些功能也會跟著不能用，所以 Hotspotly 預設只在熱點上關掉它，macOS 把它重新打開時也會在幾毫秒內再關掉。想讓它暫時開著，可以用「**允許 AirDrop 10 分鐘**」；在「**設定… → 一般**」的「**關閉 AWDL**」可以選擇在哪裡關掉它：在熱點上（預設）、在所有網路上，或永不。執行 `ifconfig awdl0`，開著的時候會顯示 `<UP,…>`。

## 命令列

app 裡附帶一個 `hotspotly` 指令。在「**設定… → 一般 → 命令列工具**」按「**安裝…**」，就會把它連結到 `/usr/local/bin/hotspotly`；也可以自己建立連結：

```sh
sudo ln -s /Applications/Hotspotly.app/Contents/MacOS/hotspotly /usr/local/bin/hotspotly
```

```
hotspotly status                 目前的狀態
hotspotly networks               記住的 Wi-Fi 網路（* = 已釘選）
hotspotly pin "<ssid>"           切換到 <ssid> 並釘選（第一次會問密碼）
hotspotly pin --here "<ssid>"    釘選目前連著的網路，名稱為 <ssid>
hotspotly unpin
hotspotly mark-hotspot           把目前的網路當成熱點
hotspotly unmark-hotspot
hotspotly pause
hotspotly resume
hotspotly awdl hotspots|all|never  在哪裡關掉 AWDL（hotspots，預設）
hotspotly allow-awdl [分鐘]      讓 AWDL 暫時開著（預設 10 分鐘）
hotspotly allow-awdl stop        提早結束
hotspotly run                    不開 app，在前景執行背景迴圈（開發用）
```

除了 `run` 之外，這些指令改的是正在執行的 app 的設定，所以 app 要開著。

## 權限

- **具管理者權限的輔助程式，只需允許一次。** 關掉 AWDL 需要 root 權限，所以 Hotspotly 附了一個小型輔助程式：app 需要時由 macOS 啟動，app 結束時跟著結束。它只做三件事：開關 AWDL、忘記你在「網路」分頁選的網路，以及把命令列工具連結到 `/usr/local/bin`。macOS 會檢查每個呼叫者都是開發者簽章的 Hotspotly.app，其他程式都無法使用它。請到「**系統設定 → 一般 → 登入項目與延伸功能 → 允許在背景執行**」允許它；「**設定… → 一般**」會顯示是否已允許。沒有它，keepalive 和釘選網路照常能用，選單會一直顯示「**允許 Hotspotly 的輔助程式…**」，直到你允許它，或在「**設定… → 一般**」把「**關閉 AWDL**」設成「**永不**」。0.6.0 以前的版本改用 sudoers 規則，輔助程式會把它移除。
- **位置（選用）。** macOS 不讓沒有位置權限的 app 讀取 Wi-Fi 名稱。允許後，選單會顯示目前的網路名稱；不允許也不影響功能，因為 Hotspotly 是用閘道的 MAC 位址來辨認網路，macOS 不會隱藏這個資訊。它不會讀取你的位置。
- **登入鑰匙圈。** 你透過 Hotspotly 釘選的網路密碼，存在 `io.github.minanyang.hotspotly` 底下。
- **網路。** 除了 ping 你的路由器，Hotspotly 每天會從 `raw.githubusercontent.com` 讀取一次 `appcast.xml` 來檢查更新，所以 GitHub 會看到來自你 IP 位址的請求。除此之外不會傳送任何資料。

## 移除

在「**設定… → 一般**」按「**解除安裝 Hotspotly…**」，它會移除輔助程式、命令列工具的連結和登入項目，並重新打開 AWDL。之後把 Hotspotly.app 丟到垃圾桶就好。

設定檔在 `~/Library/Application Support/hotspotly`。

## 授權

程式碼以 [MIT License](LICENSE) 授權。App 內更新使用 [Sparkle](https://sparkle-project.org)（MIT License），它的授權條款以 `Sparkle-LICENSE` 隨 app 一起提供。

Hotspotly 的名稱和 logo 不在 MIT License 的授權範圍內。logo 圖檔（`Resources/AppIcon.icns`、`Resources/MenuBarIcon.pdf`、`Resources/MenuBarIconFilled.pdf`、`docs/icon.png`）以及繪製 logo 的 script（`scripts/make-icons.swift`）© 2026 Min-An Yang (minanyang)，保留所有權利。fork 和衍生作品必須使用不同的名稱和 logo；註明「基於 Hotspotly」則沒有問題。
