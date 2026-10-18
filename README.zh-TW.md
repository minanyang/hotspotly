# Steady WiFi

[English](README.md) · **繁體中文**

讓 Mac 穩穩連在手機熱點和 Wi-Fi 上。

Mac 連手機熱點（iPhone 或 Android）容易斷線，原因通常不只一個。其中第一個和第三個在一般 Wi-Fi 上也會發生：

- **AWDL**：AirDrop、接力、通用控制、隨航背後用的無線連線。它會不斷把 Wi-Fi 晶片切到別的頻道，結果就是延遲突然飆高，甚至斷線。
- **熱點閒置後會關閉**：一段時間沒有流量，手機就會停止廣播熱點。
- **macOS 自己換網路**：附近有其他連過的網路（常常是別人的熱點），Mac 就跑過去了。

Steady WiFi 是一個選單列 app，每 10 秒會做這些事：

- 連在熱點上時關掉 AWDL，離開熱點後再打開，所以在一般 Wi-Fi 上 AirDrop 照常能用；
- ping 閘道，讓熱點不會因為閒置而關閉；
- 如果你釘選了某個網路，Mac 跑到別的網路時，把它拉回來。

## 安裝

需要 macOS 13（Ventura）或更新版本。

1. 下載 [SteadyWiFi.zip](https://github.com/minanyang/steady-wifi/releases/latest/download/SteadyWiFi.zip)，解壓縮後把 **SteadyWiFi** 拖進「應用程式」。
2. 打開它。Steady WiFi 目前沒有經過 Apple 公證，所以第一次打開時 macOS 會擋下來：到「**系統設定 → 隱私權與安全性**」，捲到最下面，按「**仍要打開**」。
3. 出現「完成設定」的詢問時按 **Continue**，輸入你的密碼（原因見[權限](#權限)）。
4. 詢問位置權限時按「允許」，選單才能顯示網路名稱。
5. 在選單裡打開 **Open at Login**（登入時開啟）。

熟悉終端機的話，也可以用一行指令安裝（不會遇到第 2 步的安全性警告）：

```sh
curl -fsSL https://raw.githubusercontent.com/minanyang/steady-wifi/main/install.sh | bash
```

或是用 Homebrew：

```sh
brew install --cask minanyang/tap/steadywifi
```

### 從原始碼編譯

需要 Xcode Command Line Tools。

```sh
git clone https://github.com/minanyang/steady-wifi
cd steady-wifi
make install          # 編譯 SteadyWiFi.app 並放進「應用程式」
open /Applications/SteadyWiFi.app
```

## 使用方式

所有操作都在選單列圖示的選單裡：

| 選項 | 作用 |
| --- | --- |
| **Pause / Resume** | 暫停或恢復所有功能，例如在熱點上要用 AirDrop 的時候 |
| **Pin Network** | 選一個連過的網路，讓 Mac 一直待在上面。第一次會詢問那個網路的 Wi-Fi 密碼 |
| **Current Network Is a Hotspot** | 給 Android 手機或行動網卡用。iPhone 熱點會自動偵測 |
| **Open at Login** | 登入時自動開啟 Steady WiFi |
| **Install Command Line Tool…** | 選用，見[命令列](#命令列) |

**釘選網路。** 釘選的網路是用閘道的 MAC 位址來辨認的。釘選時會切換過去一次，第一次會問你密碼：macOS 不讓其他 app 使用它存在系統鑰匙圈裡的 Wi-Fi 密碼，所以 Steady WiFi 會在你的登入鑰匙圈另存一份，而且只在連線成功後才存。如果連線失敗，就不會釘選，macOS 會自動連回它偏好的網路。

Mac 離開釘選的網路後，Steady WiFi 會先等一分鐘，之後最多每分鐘嘗試切回一次。連線失敗會讓目前的網路斷幾秒，所以連續失敗 3 次後就會停止，等 Mac 回到釘選的網路才重新計算。如果附近找不到那個網路，就不會動到目前的連線，也不算失敗；不過每次嘗試都要掃描，所以一直找不到時，間隔會拉長為 2、5、10 分鐘。iPhone 熱點閒置時會停止廣播，這時內建的 Wi-Fi 選單還能叫醒它，Steady WiFi 做不到。

結束 Steady WiFi 後，以上功能都會停止，AWDL 也會重新打開。

Log 檔在 `~/Library/Logs/steadywifi.log`（選單裡的 **Open Log**）。

## 命令列

app 裡附帶一個 `steadywifi` 指令。在選單點 **Install Command Line Tool…**，就會把它連結到 `/usr/local/bin/steadywifi`；也可以自己建立連結：

```sh
sudo ln -s /Applications/SteadyWiFi.app/Contents/MacOS/steadywifi /usr/local/bin/steadywifi
```

```
steadywifi status                 目前的狀態
steadywifi networks               記住的 Wi-Fi 網路（* = 已釘選）
steadywifi pin "<ssid>"           切換到 <ssid> 並釘選（第一次會問密碼）
steadywifi pin --here "<ssid>"    釘選目前連著的網路，名稱為 <ssid>
steadywifi unpin
steadywifi mark-hotspot           把目前的網路當成熱點
steadywifi unmark-hotspot
steadywifi pause
steadywifi resume
steadywifi run                    不開 app，在前景執行背景迴圈（開發用）
```

除了 `run` 之外，這些指令改的是正在執行的 app 的設定，所以 app 要開著。

## 權限

- **設定時輸入一次管理員密碼。** 關掉 AWDL 需要 root 權限。Steady WiFi 不會用 root 執行任何程式，而是在設定時加入 `/etc/sudoers.d/steadywifi`，讓你的帳號可以不用密碼執行兩個指令，而且只有這兩個：`/sbin/ifconfig awdl0 down` 和 `/sbin/ifconfig awdl0 up`。如果跳過這一步，keepalive 和釘選網路照常能用，選單會一直顯示 **Finish Setup…**。
- **位置（選用）。** macOS 不讓沒有位置權限的 app 讀取 Wi-Fi 名稱。允許後，選單會顯示目前的網路名稱；不允許也不影響功能，因為 Steady WiFi 是用閘道的 MAC 位址來辨認網路，macOS 不會隱藏這個資訊。它不會讀取你的位置。
- **登入鑰匙圈。** 你透過 Steady WiFi 釘選的網路密碼，存在 `io.github.minanyang.steadywifi` 底下。

## 移除

在選單選 **Uninstall Steady WiFi…**，它會移除 sudoers 規則、命令列工具的連結和登入項目，並重新打開 AWDL。之後把 SteadyWiFi.app 丟到垃圾桶就好。用 Homebrew 安裝的話：`brew uninstall --cask steadywifi`。

設定檔在 `~/Library/Application Support/steadywifi`。

## 授權

MIT
