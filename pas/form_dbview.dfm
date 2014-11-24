object DBViewer: TDBViewer
  Left = 286
  Top = 107
  Width = 716
  Height = 659
  Caption = 'DB Viewer'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Splitter1: TSplitter
    Left = 0
    Top = 521
    Width = 700
    Height = 3
    Cursor = crVSplit
    Align = alBottom
  end
  object PageControl1: TPageControl
    Left = 0
    Top = 0
    Width = 700
    Height = 521
    ActivePage = TabSheet3
    Align = alClient
    TabOrder = 0
    object TabSheet1: TTabSheet
      Caption = 'Manga data'
      OnShow = TabSheet1Show
      DesignSize = (
        692
        493)
      object Label1: TLabel
        Left = 3
        Top = 6
        Width = 75
        Height = 13
        Alignment = taRightJustify
        AutoSize = False
        Caption = 'Manga:'
        Color = clBlack
        ParentColor = False
        Transparent = True
      end
      object Label2: TLabel
        Left = 48
        Top = 57
        Width = 29
        Height = 13
        Alignment = taRightJustify
        Caption = 'Titles:'
      end
      object Label3: TLabel
        Left = 41
        Top = 136
        Width = 36
        Height = 13
        Alignment = taRightJustify
        Caption = 'Jenres:'
      end
      object Label4: TLabel
        Left = 360
        Top = 6
        Width = 57
        Height = 13
        Alignment = taRightJustify
        Caption = 'Description:'
      end
      object Label5: TLabel
        Left = 3
        Top = 33
        Width = 75
        Height = 13
        Alignment = taRightJustify
        AutoSize = False
        Caption = 'Shortcut:'
        Color = clBlack
        ParentColor = False
        Transparent = True
      end
      object cbMangasID: TComboBox
        Left = 83
        Top = 3
        Width = 271
        Height = 21
        ItemHeight = 13
        Sorted = True
        TabOrder = 0
        OnChange = cbMangasIDChange
      end
      object mTitles: TMemo
        Left = 83
        Top = 57
        Width = 271
        Height = 73
        ScrollBars = ssVertical
        TabOrder = 1
      end
      object cbJenres: TListBox
        Left = 83
        Top = 136
        Width = 271
        Height = 324
        Anchors = [akLeft, akTop, akBottom]
        ItemHeight = 13
        MultiSelect = True
        Sorted = True
        TabOrder = 2
      end
      object mDescr: TMemo
        Left = 360
        Top = 30
        Width = 329
        Height = 461
        Anchors = [akLeft, akTop, akRight, akBottom]
        TabOrder = 3
      end
      object Button3: TButton
        Left = 164
        Top = 466
        Width = 75
        Height = 25
        Anchors = [akLeft, akBottom]
        Caption = 'Save'
        TabOrder = 4
        OnClick = Button3Click
      end
      object Update: TButton
        Left = 83
        Top = 466
        Width = 75
        Height = 26
        Anchors = [akLeft, akBottom]
        Caption = 'Update'
        TabOrder = 5
        OnClick = UpdateClick
      end
      object eShortcut: TEdit
        Left = 84
        Top = 30
        Width = 229
        Height = 21
        TabOrder = 6
      end
      object bAssignShortcut: TButton
        Left = 319
        Top = 30
        Width = 35
        Height = 21
        Caption = '[->]'
        TabOrder = 7
        OnClick = bAssignShortcutClick
      end
    end
    object TabSheet2: TTabSheet
      Caption = 'eSQL'
      ImageIndex = 1
      object ListBox1: TListBox
        Left = 0
        Top = 0
        Width = 692
        Height = 402
        Align = alClient
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Courier New'
        Font.Style = []
        ItemHeight = 14
        ParentFont = False
        ScrollWidth = 16
        TabOrder = 0
      end
      object Panel1: TPanel
        Left = 0
        Top = 402
        Width = 692
        Height = 91
        Align = alBottom
        TabOrder = 1
        DesignSize = (
          692
          91)
        object Button8: TButton
          Left = 335
          Top = 4
          Width = 75
          Height = 25
          Caption = 'Show'
          TabOrder = 0
          OnClick = Button8Click
        end
        object Button4: TButton
          Left = 483
          Top = 33
          Width = 75
          Height = 25
          Caption = 'Insert'
          TabOrder = 1
          OnClick = Button4Click
        end
        object e1: TEdit
          Left = 8
          Top = 35
          Width = 89
          Height = 21
          TabOrder = 2
          Text = '0'
          OnClick = e1Click
        end
        object Edit4: TEdit
          Left = 8
          Top = 62
          Width = 469
          Height = 21
          TabOrder = 3
          Text = 'select from manga order by'
        end
        object Button9: TButton
          Left = 483
          Top = 60
          Width = 75
          Height = 25
          Caption = 'Execute'
          TabOrder = 4
          OnClick = Button9Click
        end
        object cbTables: TComboBox
          Left = 8
          Top = 8
          Width = 321
          Height = 21
          Style = csDropDownList
          ItemHeight = 13
          TabOrder = 5
        end
        object Button1: TButton
          Left = 614
          Top = 6
          Width = 75
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Load DB'
          TabOrder = 6
          OnClick = Button1Click
        end
        object Button2: TButton
          Left = 614
          Top = 37
          Width = 75
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Save DB'
          TabOrder = 7
          OnClick = Button2Click
        end
        object e2: TEdit
          Left = 103
          Top = 35
          Width = 89
          Height = 21
          TabOrder = 8
          OnClick = e1Click
        end
        object e3: TEdit
          Left = 198
          Top = 35
          Width = 89
          Height = 21
          TabOrder = 9
          OnClick = e1Click
        end
        object e4: TEdit
          Left = 293
          Top = 35
          Width = 89
          Height = 21
          TabOrder = 10
          OnClick = e1Click
        end
        object e5: TEdit
          Left = 388
          Top = 35
          Width = 89
          Height = 21
          TabOrder = 11
          OnClick = e1Click
        end
        object bOptimize: TButton
          Left = 483
          Top = 4
          Width = 75
          Height = 25
          Caption = 'Optimize'
          TabOrder = 12
          OnClick = bOptimizeClick
        end
      end
    end
    object TabSheet3: TTabSheet
      Caption = 'DB Fixup'
      ImageIndex = 2
      OnShow = TabSheet3Show
      object Panel2: TPanel
        Left = 0
        Top = 0
        Width = 185
        Height = 493
        Align = alLeft
        BevelOuter = bvNone
        TabOrder = 0
        object Label6: TLabel
          Left = 8
          Top = 84
          Width = 50
          Height = 13
          Caption = 'Manga ID:'
        end
        object Label7: TLabel
          Left = 8
          Top = 173
          Width = 57
          Height = 13
          Caption = 'Manga title:'
        end
        object Label8: TLabel
          Left = 8
          Top = 129
          Width = 45
          Height = 13
          Caption = 'Shortcut:'
        end
        object bSearchRelated: TButton
          Left = 8
          Top = 11
          Width = 169
          Height = 25
          Caption = 'Search'
          TabOrder = 0
          OnClick = bSearchRelatedClick
        end
        object Button6: TButton
          Left = 8
          Top = 42
          Width = 169
          Height = 25
          Action = aAddSel
          TabOrder = 1
        end
        object eMangaTitle: TEdit
          Left = 8
          Top = 192
          Width = 169
          Height = 21
          TabOrder = 2
        end
        object pFixpreview: TPanel
          Left = 8
          Top = 219
          Width = 169
          Height = 102
          TabOrder = 3
        end
        object Button7: TButton
          Left = 8
          Top = 103
          Width = 18
          Height = 21
          Action = aMIDPrev
          TabOrder = 4
        end
        object eMID: TEdit
          Left = 26
          Top = 103
          Width = 133
          Height = 21
          TabOrder = 5
          Text = '1'
          OnChange = eMIDChange
        end
        object Button10: TButton
          Left = 159
          Top = 103
          Width = 18
          Height = 21
          Caption = '>'
          TabOrder = 6
          OnClick = Button10Click
        end
        object eMShortcut: TEdit
          Left = 8
          Top = 148
          Width = 169
          Height = 21
          TabOrder = 7
        end
        object pFixFirstPage: TPanel
          Left = 8
          Top = 323
          Width = 169
          Height = 102
          TabOrder = 8
        end
      end
      object lvFixMangas: TListView
        Left = 185
        Top = 0
        Width = 507
        Height = 493
        Align = alClient
        Columns = <
          item
            Caption = 'Registered'
            Width = 150
          end
          item
            AutoSize = True
            Caption = 'Found'
          end>
        ReadOnly = True
        RowSelect = True
        SortType = stText
        TabOrder = 1
        ViewStyle = vsReport
        OnChange = lvFixMangasChange
      end
    end
  end
  object lLog: TListBox
    Left = 0
    Top = 524
    Width = 700
    Height = 97
    Align = alBottom
    ItemHeight = 13
    TabOrder = 1
  end
  object alActions: TActionList
    Left = 432
    Top = 320
    object aAddSel: TAction
      Caption = 'Add selected'
      OnExecute = aAddSelExecute
      OnUpdate = aAddSelUpdate
    end
    object aMIDPrev: TAction
      Caption = '<'
      OnExecute = aMIDPrevExecute
      OnUpdate = aMIDPrevUpdate
    end
    object aMIDNext: TAction
      Caption = '>'
    end
  end
end
