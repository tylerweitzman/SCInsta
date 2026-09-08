#import "CountryTable.h"

@interface CountryTable () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSArray *regionTitles; // Holds the country names
@property (nonatomic, strong) NSArray *regionCodes;  // Holds the dictionaries of country details
@property (nonatomic, strong) UITableView *tableView; // The table view to show the list

@end
@interface AWEStoreRegionChangeManager: NSObject 
- (void)p_showStoreRegionChangedDialog;
+ (id)sharedInstance;
@end
@implementation CountryTable

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Regions";
    self.regionTitles = @[@"Saudi Arabia 🇸🇦", @"Taiwan 🇹🇼", @"Hong Kong 🇭🇰", @"Macao 🇲🇴", @"Japan 🇯🇵", @"South Korea 🇰🇷", @"United Kingdom 🇬🇧", @"United States 🇺🇸", @"Australia 🇦🇺", @"Canada 🇨🇦", @"Argentina 🇦🇷", @"Philippines 🇵🇭", @"Laos 🇱🇦", @"Malaysia 🇲🇾", @"Thailand 🇹🇭", @"Singapore 🇸🇬", @"Indonesia 🇮🇩", @"Vietnam 🇻🇳", @"Anguilla 🇦🇮", @"Panama 🇵🇦", @"Germany 🇩🇪", @"Russia 🇷🇺", @"France 🇫🇷", @"Finland 🇫🇮", @"Italy 🇮🇹", @"Pakistan 🇵🇰", @"Denmark 🇩🇰", @"Norway 🇳🇴", @"Sudan 🇸🇩", @"Romania 🇷🇴", @"United Arab Emirates 🇦🇪", @"Egypt 🇪🇬", @"Lebanon 🇱🇧", @"Mexico 🇲🇽", @"Brazil 🇧🇷", @"Turkey 🇹🇷", @"Kuwait 🇰🇼", @"Algeria 🇩🇿"];
    
    self.regionCodes = @[
    @{@"area": @"Saudi Arabia 🇸🇦", @"name": @"Saudi Arabia", @"code": @"SA", @"mcc": @"420", @"mnc": @"01"},
    @{@"area": @"Taiwan 🇹🇼", @"name": @"Taiwan", @"code": @"TW", @"mcc": @"466", @"mnc": @"01"},
    @{@"area": @"Hong Kong 🇭🇰", @"name": @"Hong Kong", @"code": @"HK", @"mcc": @"454", @"mnc": @"00"},
    @{@"area": @"Macao 🇲🇴", @"name": @"Macao", @"code": @"MO", @"mcc": @"455", @"mnc": @"00"},
    @{@"area": @"Japan 🇯🇵", @"name": @"Japan", @"code": @"JP", @"mcc": @"440", @"mnc": @"00"},
    @{@"area": @"South Korea 🇰🇷", @"name": @"South Korea", @"code": @"KR", @"mcc": @"450", @"mnc": @"05"},
    @{@"area": @"United Kingdom 🇬🇧", @"name": @"United Kingdom", @"code": @"GB", @"mcc": @"234", @"mnc": @"30"},
    @{@"area": @"United States 🇺🇸", @"name": @"United States", @"code": @"US", @"mcc": @"310", @"mnc": @"00"},
    @{@"area": @"Australia 🇦🇺", @"name": @"Australia", @"code": @"AU", @"mcc": @"505", @"mnc": @"02"},
    @{@"area": @"Canada 🇨🇦", @"name": @"Canada", @"code": @"CA", @"mcc": @"302", @"mnc": @"720"},
    @{@"area": @"Argentina 🇦🇷", @"name": @"Argentina", @"code": @"AR", @"mcc": @"722", @"mnc": @"07"},
    @{@"area": @"Philippines 🇵🇭", @"name": @"Philippines", @"code": @"PH", @"mcc": @"515", @"mnc": @"02"},
    @{@"area": @"Laos 🇱🇦", @"name": @"Laos", @"code": @"LA", @"mcc": @"457", @"mnc": @"01"},
    @{@"area": @"Malaysia 🇲🇾", @"name": @"Malaysia", @"code": @"MY", @"mcc": @"502", @"mnc": @"13"},
    @{@"area": @"Thailand 🇹🇭", @"name": @"Thailand", @"code": @"TH", @"mcc": @"520", @"mnc": @"18"},
    @{@"area": @"Singapore 🇸🇬", @"name": @"Singapore", @"code": @"SG", @"mcc": @"525", @"mnc": @"01"},
    @{@"area": @"Indonesia 🇮🇩", @"name": @"Indonesia", @"code": @"ID", @"mcc": @"510", @"mnc": @"01"},
    @{@"area": @"Vietnam 🇻🇳", @"name": @"Vietnam", @"code": @"VN", @"mcc": @"452", @"mnc": @"01"},
    @{@"area": @"Anguilla 🇦🇮", @"name": @"Anguilla", @"code": @"AI", @"mcc": @"365", @"mnc": @"840"},
    @{@"area": @"Panama 🇵🇦", @"name": @"Panama", @"code": @"PA", @"mcc": @"714", @"mnc": @"04"},
    @{@"area": @"Germany 🇩🇪", @"name": @"Germany", @"code": @"DE", @"mcc": @"262", @"mnc": @"01"},
    @{@"area": @"Russia 🇷🇺", @"name": @"Russia", @"code": @"RU", @"mcc": @"250", @"mnc": @"01"},
    @{@"area": @"France 🇫🇷", @"name": @"France", @"code": @"FR", @"mcc": @"208", @"mnc": @"10"},
    @{@"area": @"Finland 🇫🇮", @"name": @"Finland", @"code": @"FI", @"mcc": @"244", @"mnc": @"91"},
    @{@"area": @"Italy 🇮🇹", @"name": @"Italy", @"code": @"IT", @"mcc": @"222", @"mnc": @"10"},
    @{@"area": @"Pakistan 🇵🇰", @"name": @"Pakistan", @"code": @"PK", @"mcc": @"410", @"mnc": @"01"},
    @{@"area": @"Denmark 🇩🇰", @"name": @"Denmark", @"code": @"DK", @"mcc": @"238", @"mnc": @"01"},
    @{@"area": @"Norway 🇳🇴", @"name": @"Norway", @"code": @"NO", @"mcc": @"242", @"mnc": @"01"},
    @{@"area": @"Sudan 🇸🇩", @"name": @"Sudan", @"code": @"SD", @"mcc": @"634", @"mnc": @"01"},
    @{@"area": @"Romania 🇷🇴", @"name": @"Romania", @"code": @"RO", @"mcc": @"226", @"mnc": @"01"},
    @{@"area": @"United Arab Emirates 🇦🇪", @"name": @"United Arab Emirates", @"code": @"AE", @"mcc": @"424", @"mnc": @"02"},
    @{@"area": @"Egypt 🇪🇬", @"name": @"Egypt", @"code": @"EG", @"mcc": @"602", @"mnc": @"01"},
    @{@"area": @"Lebanon 🇱🇧", @"name": @"Lebanon", @"code": @"LB", @"mcc": @"415", @"mnc": @"01"},
    @{@"area": @"Mexico 🇲🇽", @"name": @"Mexico", @"code": @"MX", @"mcc": @"334", @"mnc": @"030"},
    @{@"area": @"Brazil 🇧🇷", @"name": @"Brazil", @"code": @"BR", @"mcc": @"724", @"mnc": @"06"},
    @{@"area": @"Turkey 🇹🇷", @"name": @"Turkey", @"code": @"TR", @"mcc": @"286", @"mnc": @"01"},
    @{@"area": @"Kuwait 🇰🇼", @"name": @"Kuwait", @"code": @"KW", @"mcc": @"419", @"mnc": @"02"},
    @{@"area": @"Algeria 🇩🇿", @"name": @"Algeria", @"code": @"DZ", @"mcc": @"603", @"mnc": @"01"}
];

    
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

#pragma mark - UITableView DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.regionTitles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    cell.textLabel.text = self.regionTitles[indexPath.row];
    
    return cell;
}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *selectedRegion = self.regionCodes[indexPath.row];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:selectedRegion forKey:@"region"];
    [defaults synchronize];
    
    NSLog(@"Selected region: %@", selectedRegion);
    [[NSClassFromString(@"AWEStoreRegionChangeManager") sharedInstance] p_showStoreRegionChangedDialog];

}

@end
