<div align="center">

<img src="docs/icon.png" width="128" alt="Hotspotly 圖示">

# Hotspotly

讓 Mac 穩穩連在手機熱點和 Wi-Fi 上。

[![Release](https://img.shields.io/github/v/release/minanyang/hotspotly)](https://github.com/minanyang/hotspotly/releases/latest)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

[English](README.md) · **繁體中文** · [下載](https://github.com/minanyang/hotspotly/releases/latest/download/Hotspotly.zip)

</div>

Mac 連手機熱點（iPhone 或 Android）容易斷線，原因通常不只一個。其中第一個和第三個在一般 Wi-Fi 上也會發生：

- **AWDL**：AirDrop、接力、通用控制、隨航背後用的無線連線。它會不斷把 Wi-Fi 晶片切到別的頻道，結果就是延遲突然飆高，甚至斷線。見[什麼是 AWDL？](#什麼是-awdl)
- **熱點閒置後會關閉**：一段時間沒有流量，手機就會停止廣播熱點。
- **macOS 自己換網路**：附近有其他連過的網路（常常是別人的熱點），Mac 就跑過去了。

Hotspotly 是一個選單列 app，每 10 秒會做這些事：

- 連在熱點上時關掉 AWDL，離開熱點後再打開，所以在一般 Wi-Fi 上 AirDrop 照常能用；
- ping 閘道，讓熱點不會因為閒置而關閉；
- 如果你釘選了某個網路，Mac 跑到別的網路時，把它拉回來。

## 安裝

需要 macOS 13（Ventura）或更新版本。

1. 下載 [Hotspotly.zip](https://github.com/minanyang/hotspotly/releases/latest/download/Hotspotly.zip)，解壓縮後把 **Hotspotly** 拖進「應用程式」。
2. 打開它。Hotspotly 目前沒有經過 Apple 公證，所以第一次打開時 macOS 會擋下來：到「**系統設定 → 隱私權與安全性**」，捲到最下面，按「**仍要打開**」。
3. 出現「完成 Hotspotly 的設定」的詢問時按「**繼續**」，輸入你的密碼（原因見[權限](#權限)）。
4. 詢問位置權限時按「允許」，選單才能顯示網路名稱。
5. 在選單裡打開「**設定 → 登入時開啟**」。

熟悉終端機的話，也可以用一行指令安裝（不會遇到第 2 步的安全性警告）：

```sh
curl -fsSL https://raw.githubusercontent.com/minanyang/hotspotly/main/install.sh | bash
```

### 從原始碼編譯

需要 Xcode Command Line Tools。

```sh
git clone https://github.com/minanyang/hotspotly
cd hotspotly
make install          # 編譯 Hotspotly.app 並放進「應用程式」
open /Applications/Hotspotly.app
```

## 使用方式

所有操作都在選單列圖示裡。最上面的開關可以關閉或重新開啟 Hotspotly；連著熱點時會出現「**允許 AirDrop 10 分鐘**」；不常用的選項在「**設定**」裡。連著熱點時，圖示的路由器會變成實心。選單會跟著系統語言顯示繁體中文或英文。

**釘選網路。** 在「**釘選網路**」選一個網路，Mac 跑到別的網路時，Hotspotly 會把它拉回來，試幾次不成功就會停止。第一次會詢問 Wi-Fi 密碼，存在你的登入鑰匙圈，因為 macOS 不讓其他 app 使用它自己存的那份。iPhone 熱點停止廣播後，Hotspotly 叫不醒它，內建的 Wi-Fi 選單可以。

Android 手機和行動網卡不會被自動判斷成熱點，請用「**設定 → 目前的網路是熱點**」標記。結束 Hotspotly 後 AWDL 會重新打開。Log 檔在 `~/Library/Logs/hotspotly.log`。

## 什麼是 AWDL？

AWDL（Apple Wireless Direct Link）讓 Apple 裝置直接用 Wi-Fi 互相連線，AirDrop、接力、通用控制和隨航都靠它。它和你的 Wi-Fi 連線共用 Mac 唯一的一組無線電，每秒會好幾次把無線電切到別的頻道去找附近的裝置。家裡的路由器還能應付；手機熱點則常常延遲飆高，甚至斷線。

關掉 AWDL 就能解決，但那些功能也會跟著不能用，所以 Hotspotly 只在熱點上關掉它，macOS 把它重新打開時也會在幾毫秒內再關掉。想讓它開著，可以用「**允許 AirDrop 10 分鐘**」或取消勾選「**設定 → 在熱點上關閉 AWDL**」。執行 `ifconfig awdl0`，開著的時候會顯示 `<UP,…>`。

## 命令列

app 裡附帶一個 `hotspotly` 指令。在選單點「**設定 → 安裝命令列工具…**」，就會把它連結到 `/usr/local/bin/hotspotly`；也可以自己建立連結：

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
hotspotly awdl on|off            在熱點上關掉 AWDL（on，預設）或完全不管它（off）
hotspotly allow-awdl [分鐘]      讓 AWDL 暫時開著（預設 10 分鐘）
hotspotly allow-awdl stop        提早結束
hotspotly run                    不開 app，在前景執行背景迴圈（開發用）
```

除了 `run` 之外，這些指令改的是正在執行的 app 的設定，所以 app 要開著。

## 權限

- **設定時輸入一次管理員密碼。** 關掉 AWDL 需要 root 權限。Hotspotly 不會用 root 執行任何程式，而是在設定時加入 `/etc/sudoers.d/hotspotly`，讓你的帳號可以不用密碼執行兩個指令，而且只有這兩個：`/sbin/ifconfig awdl0 down` 和 `/sbin/ifconfig awdl0 up`。如果跳過這一步，keepalive 和釘選網路照常能用，選單會一直顯示「**完成設定…**」，直到你完成設定，或取消勾選「**設定 → 在熱點上關閉 AWDL**」。
- **位置（選用）。** macOS 不讓沒有位置權限的 app 讀取 Wi-Fi 名稱。允許後，選單會顯示目前的網路名稱；不允許也不影響功能，因為 Hotspotly 是用閘道的 MAC 位址來辨認網路，macOS 不會隱藏這個資訊。它不會讀取你的位置。
- **登入鑰匙圈。** 你透過 Hotspotly 釘選的網路密碼，存在 `io.github.minanyang.hotspotly` 底下。

## 移除

在選單選「**設定 → 解除安裝 Hotspotly…**」，它會移除 sudoers 規則、命令列工具的連結和登入項目，並重新打開 AWDL。之後把 Hotspotly.app 丟到垃圾桶就好。

設定檔在 `~/Library/Application Support/hotspotly`。

## 授權

程式碼以 [MIT License](LICENSE) 授權。

Hotspotly 的名稱和 logo 不在 MIT License 的授權範圍內。logo 圖檔（`Resources/AppIcon.icns`、`Resources/MenuBarIcon.pdf`、`Resources/MenuBarIconFilled.pdf`、`docs/icon.png`）以及繪製 logo 的 script（`scripts/make-icons.swift`）© 2026 Min-An Yang (minanyang)，保留所有權利。fork 和衍生作品必須使用不同的名稱和 logo；註明「基於 Hotspotly」則沒有問題。
