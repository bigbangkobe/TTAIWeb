import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'AppLocalizations.dart';
import 'LanguageManager.dart';


class LanguageSelectionScreen extends ConsumerStatefulWidget {
  final String pageKey; // 页面标识，区分不同页面的语言选择
  final Function(int index) callback;
  final int currentIndex;

  const LanguageSelectionScreen({
    Key? key,
    required this.pageKey,
    required this.currentIndex,
    required this.callback,
  }) : super(key: key);

  @override
  _LanguageSelectionScreenState createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  late int selectedIndex;
  @override
  void initState() {
    super.initState();
    selectedIndex = widget.currentIndex;
    if (widget.pageKey == "BinauralMode") {
      ref.read(languageProvider.notifier).loadLanguages('languagesbm');
    }else{// 确保加载语言数据
      ref.read(languageProvider.notifier).loadLanguages('languages');}
  }

  @override
  Widget build(BuildContext context) {
    // 监听语言加载的状态（AsyncValue）
    final languageAsync = ref.watch(languageProvider);
    final localization = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('语言选择')),
        centerTitle: true, // 使标题居中
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            if (languageAsync is AsyncData &&
                languageAsync.value != null &&
                languageAsync.value!.languages.isNotEmpty) {
              final selectedLanguage = languageAsync.value!.getLanguage(selectedIndex);
              Navigator.pop(context, selectedLanguage);
            } else {
              Navigator.pop(context, null);
            }
          },
        ),
      ),
      body: languageAsync.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text(localization.translate('加载语言失败') + ': $error')),
        data: (languageState) {
          return Container(
            color: Colors.white, // 设置底部背景为白色
            child: ListView.builder(
              itemCount: languageState.languages.length,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                          color: Colors.grey, width: 0.5), // 添加底部灰色横线
                    ),
                  ),
                  child: ListTile(
                    title: Text(languageState.languages[index]['localName'] ?? ''),
                    subtitle: Text(languageState.languages[index]['displayName'] ?? ''),
                    trailing: Icon(
                      Icons.check,
                      color: selectedIndex == index
                          ? Colors.blue
                          : Colors.transparent,
                    ),
                    onTap: () {
                      setState(() {
                        selectedIndex = index;
                      });
                      // 更新 Riverpod 状态，确保该页面的语言选择被保存
                      //ref.read(languageSelectionProvider(widget.pageKey).notifier).selectLeftLanguage(index);

                      widget.callback.call(index);
                      // widget.currentIndex=index;
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
