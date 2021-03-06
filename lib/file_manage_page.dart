import 'package:flutter/material.dart';
import 'search_result_view.dart';
import 'bucket_view.dart';
import 'click_effect.dart';
import 'package:flutter_easyrefresh/easy_refresh.dart';
import 'oss.dart';
import 'drawer_view.dart';
import 'photo_gallery_page.dart';
import 'event_bus.dart';
import 'package:picbox/video_page.dart';
import 'file.dart';
import 'translations.dart';
import 'details_page.dart';

class FileManagePage extends StatefulWidget {

    @override
    _FileManagePageState createState() => _FileManagePageState();
}

class _FileManagePageState extends State<FileManagePage> with AutomaticKeepAliveClientMixin {
    
    GlobalKey<EasyRefreshState> _easyRefreshKey = new GlobalKey<EasyRefreshState>();
    GlobalKey<RefreshHeaderState> _headerKey = new GlobalKey<RefreshHeaderState>();

    ScrollController controller = ScrollController();
    
    final SearchControllerDelegate _delegate = SearchControllerDelegate();
    final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
    int _lastIntegerSelected;

    Oss oss = new Oss();
    String prefix,marker;
    List<double> position = [];
    List<File> files = [];
    List<String> gallery = [];
    List<String> prefixS = [];

    Translations trans;
    
    @override
    bool get wantKeepAlive => true;
    
    @override
    void initState() {
        super.initState();
        initAsync();
    }

    void initAsync() async {
        bus.on('file_manage_page.changeBucket', (args){
            _clear();
            oss.changeBucket(args);
            _easyRefreshKey.currentState.callRefresh();
        });

        bus.on('file_manage_page.changeAccount', (args){
            _clear();
            oss.changeAccount(args);
            _easyRefreshKey.currentState.callRefresh();
        });
    }

    void _clear() {
        prefixS = [];
        prefix = null;
        position = [];
    }

    IconData _backIcon() {
        if(Theme.of(context).platform == TargetPlatform.iOS) {
            return Icons.arrow_back_ios;
        }
        else {
            return Icons.arrow_back;
        }
    }
    
    _uploads() async {
        Map map = await oss.upload();
        print(map);
        _easyRefreshKey.currentState.callRefresh();
    }

    //仅网盘需求，不需要分页功能
    _pull({String prefix,bool clear=true,String delimiter='/',int maxKeys=1000}) async {
        if(clear) {
            files.clear();
            gallery.clear();
            marker = null;
        }
        Map result = await oss.bucket(prefix:prefix,delimiter:delimiter,maxKeys:maxKeys,marker:marker);
        for (var item in result['commonPrefixes']) {
            files.add(File(true,item['Prefix'],prefix));
        }
        for (var item in result['contents']) {
            if(item['Size'] == '0') {
                continue;
            }
            File file = File(false,item['Key'],prefix,size: item['Size'],date:item['LastModified']);
            if(file.isImage) {
                gallery.add(item['Key']);
                file.index =  gallery.length - 1;
            }
            files.add(file);
        }
        setState(() {
            marker = result['marker'];
        });
    }
    
    void _fileTap(File file) {
        //如果是文件夹
        if (file.isDir) {
            position.insert(position.length, controller.offset);
            prefixS.add(file.name);
            prefix = prefixS.join('/')+"/";
            print("prefix $prefix");
            _pull(prefix:prefix,clear: true);
            jumpToPosition(true);
            return;
        }
        //如果是图片
        if(file.isImage) {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => new PhotoGalleryPage(oss,file.index,gallery))
            );
            return;
        }
        //如果是视频
        if(file.isVideo) {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => VideoPage(
                oss,file.name,file.key,
            )));
        }
    }
    
    @override
    Widget build(BuildContext context) {

        trans = Translations.of(context);

        return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
                leading: null == prefix?null : IconButton(
                    icon: Icon(_backIcon()),
                    onPressed: () {
                        prefixS.removeLast();
                        if (prefixS.isEmpty) {
							prefix = null;
                            _pull();
                            jumpToPosition(false);
                        }
                        else {
                            prefix = prefixS.join('/')+"/";
                            _pull(prefix:prefix);
                            jumpToPosition(true);
                        }
                    }),
                title: Text(trans.text('main_title')),//'网盘盒子'
                actions: <Widget>[
                    IconButton(
						tooltip: 'Search',
						icon: const Icon(Icons.search),
						onPressed: () async {
							final int selected = await showSearch<int>(
								context: context,
								delegate: _delegate,
							);
							if (selected != null && selected != _lastIntegerSelected) {
								setState(() {
									_lastIntegerSelected = selected;
								});
							}
						},
                    ),
                    IconButton(
                        icon: Icon(Icons.add),
                        tooltip: 'Upload Files',
                        onPressed:() {
                            _uploads();
                        }
                    ),
                    IconButton(
                        icon: Icon(
                            Theme.of(context).platform == TargetPlatform.iOS
                                ? Icons.more_horiz
                                : Icons.more_vert,
                        ),
                        tooltip: 'Show Bucket',
                        onPressed: (){
                            showModalBottomSheet<void>(context: context, builder: (BuildContext context) {
                                return BucketView(oss);
                            });
                        }
                    ),

                ],
            ),
            drawer: DrawerView(oss),
            body: Scaffold(
                appBar: PreferredSize(
                    child: AppBar(
                        elevation: 0.4,
                        centerTitle: false,
                        backgroundColor: Color(0xffeeeeee),
                        title: Text(
                            "/${oss.bucketName}/"+(prefix==null?"":"$prefix"),
                            style: TextStyle(color: Colors.grey),
                        ),
                    ),
                    preferredSize: Size.fromHeight(30)
                ),
                backgroundColor: Color(0xfff3f3f3),
                body: EasyRefresh(
                    key: _easyRefreshKey,
                    firstRefresh: true,
                    behavior: ScrollOverBehavior(),
                    refreshHeader:ClassicsHeader(
                        key: _headerKey,
                        refreshText: trans.text('pullToRefresh'),
                        refreshReadyText: trans.text('releaseToRefresh'),
                        refreshingText: trans.text('refreshing'),
                        refreshedText: trans.text('refreshFinish'),
                        moreInfo: trans.text('updateAt'),
                        bgColor: Colors.transparent,
                        textColor: Colors.black87,
                        moreInfoColor: Colors.black54,
                        showMore: true,
                    ),
                    child:ListView.builder(
                        controller: controller,
                        itemCount: files.length != 0 ? files.length : 1,
                        itemBuilder: (BuildContext context, int index) {
                            if (files.length != 0) {
                                return buildListViewItem(files[index]);
                            }
                            else {
                                return Padding(
                                    padding: EdgeInsets.only(top: MediaQuery.of(context).size.height / 2 - MediaQuery.of(context).padding.top - 56.0),
                                    child: Center(
                                        child: Text('The folder is empty'),
                                    ),
                                );
                            }
                        },
                    ),
                    onRefresh:() => _pull(prefix: prefix),
                )
            ),//SearchResultView(),
        );
    }

    Widget buildListViewItem(File file) {
        return ClickEffect(
            child: Column(
                children: <Widget>[
                    ListTile(
                        leading: Image.asset(fileIcon(file)),
                        title: Row(
                            children: <Widget>[
                                Expanded(child: Text(file.name)),
                                //file.isDir? Text('${file.num}项',style: TextStyle(color: Colors.grey)):Container()
                            ],
                        ),
                        subtitle: file.isDir ? null:Text('${file.dateFmt()}  ${file.sizeFmt()}', style: TextStyle(fontSize: 12.0)),
                        trailing: _trailing(file),
                    ),
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Divider(height: 1.0),
                    )
                ],
            ),
            onTap: () => _fileTap(file),
        );
    }

    Widget _trailing(file) {
        //file.isDir ? Icon(Icons.chevron_right):
        return GestureDetector(
            child: Icon(Icons.info_outline),
            onTap: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => new DetailsPage())
                );
            },//点击
        );
    }

    void jumpToPosition(bool isEnter) {
        if (isEnter) {
            controller.jumpTo(0.0);
        }
        else {
            controller.jumpTo(position[position.length - 1]);
            position.removeLast();
        }
    }

    String fileIcon(File file) {
        try {
            String iconImg;
            if (file.isDir) {
                return 'assets/images/folder.png';
            }
            switch (file.ext) {
                case '.ppt':
                case '.pptx':
                    iconImg = 'assets/images/ppt.png';
                    break;
                case '.doc':
                case '.docx':
                    iconImg = 'assets/images/word.png';
                    break;
                case '.xls':
                case '.xlsx':
                    iconImg = 'assets/images/excel.png';
                    break;
                case '.jpg':
                case '.jpeg':
                case '.png':
                    iconImg = 'assets/images/image.png';
                    break;
                case '.txt':
                    iconImg = 'assets/images/txt.png';
                    break;
                case '.mp3':
                    iconImg = 'assets/images/mp3.png';
                    break;
                case '.mp4':
                    iconImg = 'assets/images/video.png';
                    break;
                case '.rar':
                case '.zip':
                    iconImg = 'assets/images/zip.png';
                    break;
                case '.psd':
                    iconImg = 'assets/images/psd.png';
                    break;
                default:
                    iconImg = 'assets/images/file.png';
                    break;
            }
            return iconImg;
        }
        catch (e) {
            return 'assets/images/unknown.png';
        }
    }
}



