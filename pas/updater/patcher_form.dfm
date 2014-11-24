object MainViewer: TMainViewer
  Left = 454
  Top = 58
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = #1055#1072#1090#1095#1077#1088' Ergo'
  ClientHeight = 319
  ClientWidth = 549
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 16
    Width = 40
    Height = 13
    Caption = #1042#1077#1088#1089#1080#1103':'
  end
  object bMakePatch: TButton
    Left = 160
    Top = 40
    Width = 75
    Height = 25
    Caption = #1057#1086#1079#1076#1072#1090#1100' '#1087#1072#1090#1095
    TabOrder = 0
    OnClick = bMakePatchClick
  end
  object eVHi: TEdit
    Left = 64
    Top = 13
    Width = 41
    Height = 21
    TabOrder = 1
    Text = '1'
  end
  object eVLow: TEdit
    Left = 112
    Top = 13
    Width = 41
    Height = 21
    TabOrder = 2
    Text = '0'
  end
  object bWriteVersion: TButton
    Left = 160
    Top = 10
    Width = 75
    Height = 25
    Caption = #1047#1072#1087#1080#1089#1100' '#1074#1077#1088#1089#1080#1080
    TabOrder = 3
    OnClick = bWriteVersionClick
  end
  object lbLog: TListBox
    Left = 0
    Top = 130
    Width = 549
    Height = 189
    Align = alBottom
    ItemHeight = 13
    TabOrder = 4
  end
  object mDirs: TMemo
    Left = 240
    Top = 8
    Width = 161
    Height = 113
    Lines.Strings = (
      'html')
    ScrollBars = ssVertical
    TabOrder = 5
  end
  object mFiles: TMemo
    Left = 408
    Top = 8
    Width = 137
    Height = 113
    ScrollBars = ssVertical
    TabOrder = 6
  end
end
