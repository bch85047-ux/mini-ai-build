#ifndef ROOTS_H
#define ROOTS_H
#import <Foundation/Foundation.h>

NSString *RootsDir(void);
NSString *RootfsPath(void);
BOOL RootfsReady(void);
NSString *RootfsExtractDir(void);
BOOL RootfsNeedsDownload(void);
NSString *PartsBaseDir(void);
NSError *RootfsMergeParts(void);

#endif
