<div align="center">

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
3. 出現「完成設定」的詢問時按 **Continue**，輸入你的密碼（原因見[權限](#權限)）。
4. 詢問位置權限時按「允許」，選單才能顯示網路名稱。
5. 在選單裡打開 **Open at Login**（登入時開啟）。

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

所有操作都在選單列圖示的選單裡：

| 選項 | 作用 |
| --- | --- |
| **Pause / Resume** | 暫停或恢復所有功能 |
| **Turn Off AWDL on Hotspots** | 預設開啟。關掉後，在熱點上也能照常用 AirDrop、通用控制等功能；keepalive 和釘選網路照常運作 |
| **Allow AirDrop for 10 Minutes** | 讓 AWDL 開著 10 分鐘，時間到再關掉。選單會顯示剩下的時間，也可以提早結束 |
| **Pin Network** | 選一個連過的網路，讓 Mac 一直待在上面。第一次會詢問那個網路的 Wi-Fi 密碼 |
| **Current Network Is a Hotspot** | 給 Android 手機或行動網卡用。iPhone 熱點會自動偵測 |
| **Open at Login** | 登入時自動開啟 Hotspotly |
| **Install Command Line Tool…** | 選用，見[命令列](#命令列) |

**釘選網路。** 釘選的網路是用閘道的 MAC 位址來辨認的。釘選時會切換過去一次，第一次會問你密碼：macOS 不讓其他 app 使用它存在系統鑰匙圈裡的 Wi-Fi 密碼，所以 Hotspotly 會在你的登入鑰匙圈另存一份，而且只在連線成功後才存。如果連線失敗，就不會釘選，macOS 會自動連回它偏好的網路。

Mac 離開釘選的網路後，Hotspotly 會先等一分鐘，之後最多每分鐘嘗試切回一次。連線失敗會讓目前的網路斷幾秒，所以連續失敗 3 次後就會停止，等 Mac 回到釘選的網路才重新計算。如果附近找不到那個網路，就不會動到目前的連線，也不算失敗；不過每次嘗試都要掃描，所以一直找不到時，間隔會拉長為 2、5、10 分鐘。iPhone 熱點閒置時會停止廣播，這時內建的 Wi-Fi 選單還能叫醒它，Hotspotly 做不到。

結束 Hotspotly 後，以上功能都會停止，AWDL 也會重新打開。

Log 檔在 `~/Library/Logs/hotspotly.log`（選單裡的 **Open Log**）。

## 什麼是 AWDL？

AWDL（Apple Wireless Direct Link）是 Apple 裝置之間不經過路由器、直接用 Wi-Fi 互相連線的技術，在 Mac 上就是 `awdl0` 這個網路介面。AirDrop、隔空播放到附近的裝置、接力、通用控制、隨航和接續互通相機都會用到它。

Mac 只有一組 Wi-Fi 無線電，AWDL 和你的 Wi-Fi 連線要共用。AWDL 每秒會好幾次把無線電切到它自己的頻道（通常是 6、44 或 149），去找附近的 Apple 裝置。切走的那段時間，Mac 收不到你網路的封包，於是延遲突然變高、掉封包。家裡的路由器比較能容忍這種情況；手機熱點的無線電比較弱、省電機制比較積極，手機本身也在跑 AWDL，所以常常直接斷線。

關掉 AWDL 就能解決這個問題，但在打開之前，AirDrop、通用控制、隨航這些功能都不能用。所以 Hotspotly 只在你連著熱點時才關掉它，需要時可以用 **Allow AirDrop for 10 Minutes** 暫時打開，或取消勾選 **Turn Off AWDL on Hotspots** 讓它一直開著。只要有這些功能需要 AWDL，macOS 就會把它重新打開，所以 Hotspotly 會一直盯著，一被打開就在幾毫秒內關掉。

想自己看它的狀態：執行 `ifconfig awdl0`，開著的時候會顯示 `<UP,…>`。

## 命令列

app 裡附帶一個 `hotspotly` 指令。在選單點 **Install Command Line Tool…**，就會把它連結到 `/usr/local/bin/hotspotly`；也可以自己建立連結：

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

- **設定時輸入一次管理員密碼。** 關掉 AWDL 需要 root 權限。Hotspotly 不會用 root 執行任何程式，而是在設定時加入 `/etc/sudoers.d/hotspotly`，讓你的帳號可以不用密碼執行兩個指令，而且只有這兩個：`/sbin/ifconfig awdl0 down` 和 `/sbin/ifconfig awdl0 up`。如果跳過這一步，keepalive 和釘選網路照常能用，選單會一直顯示 **Finish Setup…**，直到你完成設定，或取消勾選 **Turn Off AWDL on Hotspots**。
- **位置（選用）。** macOS 不讓沒有位置權限的 app 讀取 Wi-Fi 名稱。允許後，選單會顯示目前的網路名稱；不允許也不影響功能，因為 Hotspotly 是用閘道的 MAC 位址來辨認網路，macOS 不會隱藏這個資訊。它不會讀取你的位置。
- **登入鑰匙圈。** 你透過 Hotspotly 釘選的網路密碼，存在 `io.github.minanyang.hotspotly` 底下。

## 移除

在選單選 **Uninstall Hotspotly…**，它會移除 sudoers 規則、命令列工具的連結和登入項目，並重新打開 AWDL。之後把 Hotspotly.app 丟到垃圾桶就好。

設定檔在 `~/Library/Application Support/hotspotly`。

## 授權

MIT
