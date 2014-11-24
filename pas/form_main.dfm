object MainViewer: TMainViewer
  Left = 293
  Top = 165
  ClientHeight = 456
  ClientWidth = 738
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  Position = poDesktopCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 738
    Height = 456
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object Splitter1: TSplitter
      Left = 0
      Top = 404
      Width = 738
      Height = 3
      Cursor = crVSplit
      Align = alBottom
      ExplicitTop = 429
    end
    object lLog: TListBox
      Left = 0
      Top = 407
      Width = 738
      Height = 49
      Align = alBottom
      ItemHeight = 13
      TabOrder = 0
    end
    object PageControl1: TPageControl
      Left = 0
      Top = 0
      Width = 738
      Height = 404
      ActivePage = TabSheet2
      Align = alClient
      TabOrder = 1
      object TabSheet1: TTabSheet
        Caption = 'Server'
        DesignSize = (
          730
          376)
        object Label1: TLabel
          Left = 37
          Top = 11
          Width = 14
          Height = 13
          Caption = 'IP:'
        end
        object Edit1: TEdit
          Left = 56
          Top = 8
          Width = 121
          Height = 21
          TabOrder = 0
          Text = '127.0.0.1'
        end
        object Edit2: TEdit
          Left = 183
          Top = 8
          Width = 121
          Height = 21
          TabOrder = 1
          Text = '1122'
        end
        object Edit4: TEdit
          Left = 354
          Top = 355
          Width = 376
          Height = 21
          Anchors = [akRight, akBottom]
          ReadOnly = True
          TabOrder = 2
        end
        object mSrvResp: TMemo
          Left = 8
          Top = 42
          Width = 340
          Height = 334
          Anchors = [akLeft, akTop, akRight, akBottom]
          Color = clBtnFace
          ReadOnly = True
          ScrollBars = ssBoth
          TabOrder = 3
        end
        object RadioGroup2: TRadioGroup
          Left = 354
          Top = 277
          Width = 376
          Height = 94
          Anchors = [akRight, akBottom]
          Caption = 'Err Codes:'
          Enabled = False
          Items.Strings = (
            'No error'
            'Manga by id not found'
            'Chapter doesn'#39't exists'
            'Image doesn'#39't exist or not yet precached'
            'Manga already on updating process'
            'Request doesn'#39't recognized by server'
            'Request contains errors or internal error while parsing request')
          TabOrder = 4
        end
        object RadioGroup1: TRadioGroup
          Left = 354
          Top = 64
          Width = 173
          Height = 207
          Anchors = [akTop, akRight, akBottom]
          Caption = 'Response type:'
          Enabled = False
          Items.Strings = (
            'State OK or not recognized'
            'Manga list'
            'Manga description'
            'Manga image data'
            'Mangas list on source servers'
            'Manga loaded'
            'State ERR')
          TabOrder = 5
        end
        object Memo1: TMemo
          Left = 533
          Top = 64
          Width = 197
          Height = 207
          Anchors = [akTop, akRight, akBottom]
          Color = clBtnFace
          ReadOnly = True
          ScrollBars = ssBoth
          TabOrder = 6
        end
      end
      object TabSheet2: TTabSheet
        Caption = 'Client'
        ImageIndex = 1
        object PageControl2: TPageControl
          Left = 0
          Top = 0
          Width = 730
          Height = 376
          ActivePage = tsMangaSearch
          Align = alClient
          TabOrder = 0
          object tsMangaList: TTabSheet
            Caption = 'Manga list'
            OnShow = tsMangaListShow
            DesignSize = (
              722
              348)
            object lbSrvCachedManga: TListBox
              Left = 3
              Top = 3
              Width = 322
              Height = 342
              Anchors = [akLeft, akTop, akBottom]
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clWindowText
              Font.Height = -11
              Font.Name = 'Courier New'
              Font.Style = []
              ItemHeight = 14
              ParentFont = False
              TabOrder = 0
              OnDblClick = lbSrvCachedMangaDblClick
            end
          end
          object tsMangaSearch: TTabSheet
            Caption = 'Searching'
            ImageIndex = 1
            OnShow = tsMangaSearchShow
            DesignSize = (
              722
              348)
            object lbSearchList: TListBox
              AlignWithMargins = True
              Left = 3
              Top = 3
              Width = 716
              Height = 314
              Anchors = [akLeft, akTop, akRight, akBottom]
              ItemHeight = 13
              TabOrder = 0
              OnDblClick = lbFilterListDblClick
            end
            object eListFilter: TEdit
              Left = 3
              Top = 324
              Width = 653
              Height = 21
              Anchors = [akLeft, akRight, akBottom]
              TabOrder = 1
              OnChange = eListFilterChange
              OnKeyPress = eListFilterKeyPress
            end
            object lbFilterList: TListBox
              AlignWithMargins = True
              Left = 3
              Top = 3
              Width = 716
              Height = 314
              Anchors = [akLeft, akTop, akRight, akBottom]
              ItemHeight = 13
              TabOrder = 2
              Visible = False
              OnDblClick = lbFilterListDblClick
            end
            object seMatcing: TSpinEdit
              Left = 662
              Top = 323
              Width = 57
              Height = 22
              Anchors = [akRight, akBottom]
              MaxValue = 1000
              MinValue = 0
              TabOrder = 3
              Value = 1
              OnChange = eListFilterChange
            end
          end
          object tsMangaDescr: TTabSheet
            Caption = 'Manga desc'
            ImageIndex = 2
            DesignSize = (
              722
              348)
            object Image1: TImage
              Left = 3
              Top = 73
              Width = 142
              Height = 144
            end
            object lMangaTitle: TLabel
              Left = 151
              Top = 4
              Width = 568
              Height = 25
              Anchors = [akLeft, akTop, akRight]
              AutoSize = False
              Color = clAppWorkSpace
              ParentColor = False
              Transparent = False
              ExplicitWidth = 556
            end
            object lMangaAlts: TLabel
              Left = 3
              Top = 223
              Width = 290
              Height = 122
              Anchors = [akLeft, akTop, akBottom]
              AutoSize = False
              Color = clAppWorkSpace
              ParentColor = False
              Transparent = False
              ExplicitHeight = 115
            end
            object lMangaJenres: TLabel
              Left = 151
              Top = 76
              Width = 142
              Height = 141
              AutoSize = False
              Color = clAppWorkSpace
              ParentColor = False
              Transparent = False
            end
            object lMangaStatus: TLabel
              Left = 151
              Top = 35
              Width = 568
              Height = 25
              Anchors = [akLeft, akTop, akRight]
              AutoSize = False
              Color = clAppWorkSpace
              ParentColor = False
              Transparent = False
              ExplicitWidth = 561
            end
            object mMangaDesc: TMemo
              Left = 299
              Top = 73
              Width = 420
              Height = 272
              Anchors = [akLeft, akTop, akRight, akBottom]
              Color = clBtnFace
              ReadOnly = True
              ScrollBars = ssVertical
              TabOrder = 0
            end
            object Button6: TButton
              Left = 3
              Top = 4
              Width = 142
              Height = 25
              Caption = 'Update'
              TabOrder = 1
              OnClick = Button6Click
            end
            object Button7: TButton
              Left = 3
              Top = 35
              Width = 142
              Height = 25
              Caption = 'Read'
              TabOrder = 2
            end
          end
        end
      end
      object TabSheet3: TTabSheet
        Caption = 'ESQL'
        ImageIndex = 2
        DesignSize = (
          730
          376)
        object mESQL: TMemo
          Left = 3
          Top = 3
          Width = 724
          Height = 339
          Anchors = [akLeft, akTop, akRight, akBottom]
          Lines.Strings = (
            'status table manga;')
          TabOrder = 0
        end
        object Button1: TButton
          Left = 652
          Top = 348
          Width = 75
          Height = 25
          Anchors = [akRight, akBottom]
          Caption = 'Execute'
          TabOrder = 1
          OnClick = Button1Click
        end
      end
    end
  end
end
